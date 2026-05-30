import WebKit
import UIKit

@MainActor
class WebStatusFetcher: NSObject, StatusFetching {
    private let webView: WKWebView
    private var continuation: CheckedContinuation<CaseStatus, Error>?
    private var pendingReceipt: String?

    // Hash of the Next.js Server Action that returns case status.
    // If USCIS redeploys, this may change and the app will need an update.
    private static let nextActionId = "40122ab8357d243c3e52fd6c6786292f88f0a5be85"
    private static let routerStateTree = "[\"\",{\"children\":[[\"locale\",\"en\",\"d\",null],{\"children\":[\"__PAGE__\",{},null,null,0]},null,null,0]},null,null,16]"

    override init() {
        webView = WKWebView(frame: CGRect(x: -1000, y: -1000, width: 375, height: 812))
        super.init()
        webView.navigationDelegate = self
    }

    func fetchStatus(receiptNumber: String) async throws -> CaseStatus {
        attachToWindowIfNeeded()
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.pendingReceipt = receiptNumber
            webView.load(URLRequest(url: URL(string: "https://egov.uscis.gov/")!))
        }
    }

    private func attachToWindowIfNeeded() {
        guard webView.window == nil else { return }
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first?
            .addSubview(webView)
    }

    private func performFetchIfReady() {
        guard let receipt = pendingReceipt, continuation != nil else { return }

        webView.evaluateJavaScript("document.title") { [weak self] result, _ in
            guard let self else { return }
            let title = result as? String ?? ""
            if title.contains("Just a moment") { return }
            self.pendingReceipt = nil
            self.callServerAction(receipt: receipt)
        }
    }

    private func callServerAction(receipt: String) {
        let safeReceipt = receipt.replacingOccurrences(of: "\"", with: "")
        let escapedRouterState = Self.routerStateTree
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let js = """
        const res = await fetch("https://egov.uscis.gov/", {
            method: "POST",
            headers: {
                "accept": "text/x-component",
                "content-type": "text/plain;charset=UTF-8",
                "next-action": "\(Self.nextActionId)",
                "next-router-state-tree": encodeURIComponent("\(escapedRouterState)")
            },
            body: '["\(safeReceipt)"]',
            credentials: "include"
        });
        return await res.text();
        """

        webView.callAsyncJavaScript(js, in: nil, in: .defaultClient) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let value):
                let text = value as? String ?? ""
                if let status = self.parseServerActionResponse(text) {
                    self.continuation?.resume(returning: status)
                } else {
                    self.continuation?.resume(throwing: USCISError.invalidResponse)
                }
                self.continuation = nil

            case .failure(let error):
                self.continuation?.resume(throwing: error)
                self.continuation = nil
            }
        }
    }

    // Next.js Server Action responses are newline-separated lines of `<index>:<json>`.
    // Walk every JSON payload, recursively, looking for something that resembles a case status.
    private func parseServerActionResponse(_ text: String) -> CaseStatus? {
        for line in text.split(separator: "\n") {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let jsonStr = String(line[line.index(after: colon)...])
            guard let data = jsonStr.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: data, options: [.allowFragments])
            else { continue }
            if let status = extractStatus(from: parsed) { return status }
        }
        return nil
    }

    private func extractStatus(from obj: Any) -> CaseStatus? {
        if let dict = obj as? [String: Any] {
            // USCIS Server Action shape: { detailsEng: { actionCodeText, actionCodeDesc } }
            if let title = dict["actionCodeText"] as? String, !title.isEmpty {
                let rawDesc = dict["actionCodeDesc"] as? String ?? ""
                return CaseStatus(title: title, description: stripHTML(rawDesc))
            }
            // Prefer English when both detailsEng and detailsEs are present
            if let eng = dict["detailsEng"], let status = extractStatus(from: eng) {
                return status
            }
            for (key, value) in dict where key != "detailsEs" {
                if let nested = extractStatus(from: value) { return nested }
            }
        }
        if let arr = obj as? [Any] {
            for item in arr {
                if let nested = extractStatus(from: item) { return nested }
            }
        }
        return nil
    }

    private func stripHTML(_ s: String) -> String {
        var result = ""
        var inTag = false
        for char in s {
            if char == "<" { inTag = true }
            else if char == ">" { inTag = false }
            else if !inTag { result.append(char) }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension WebStatusFetcher: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        performFetchIfReady()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleNavigationFailure(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleNavigationFailure(error)
    }

    private func handleNavigationFailure(_ error: Error) {
        // Cloudflare cancels the initial navigation to inject its challenge.
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
        continuation?.resume(throwing: error)
        continuation = nil
        pendingReceipt = nil
    }
}
