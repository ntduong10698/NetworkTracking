//
//  ViewController.swift
//  NetworkLogger
//
//  Created by Dương Nguyễn on 29/12/2023.
//

import UIKit
import WebKit
import SwiftSoup
import SwiftyJSON

class ViewController: UIViewController, WKNavigationDelegate {
    
    var webView: WKWebView!
    let LINK_MAIN = "https://ads.tiktok.com/business/creativecenter/inspiration/popular/hashtag/pc/en"

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }
    
    //hàm đăng kí nhận sự kiện network log
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(updateNetworkLog), name: .didReceiveURLRequest, object: nil)
    }
    
    //hàm huỷ sự kiện network log
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: .didReceiveURLRequest, object: nil)
        URLProtocol.unregisterClass(WebKitURLProtocol.self)
        URLProtocol.wk_unregister(scheme: "https")
        URLProtocol.wk_unregister(scheme: "http")
        let types = Set([WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache])
        let date = Date(timeIntervalSince1970: 0)
        WKWebsiteDataStore.default().removeData(ofTypes: types, modifiedSince: date, completionHandler: {
        })
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Handle navigation completion if needed
    }
    
    func setupView() {
        URLProtocol.registerClass(WebKitURLProtocol.self)
        URLProtocol.wk_register(scheme: "https")
        URLProtocol.wk_register(scheme: "http")
        
        webView = WKWebView(frame: view.bounds)
        webView.navigationDelegate = self
        view.addSubview(webView)
        if let url = URL(string: LINK_MAIN) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    func isMatching(inString string: String) -> Bool {
        do {
            let pattern = ".+\\/creative_radar_api\\/v1\\/popular_trend\\/[A-Za-z]+\\/list.*"
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: string.utf16.count)
            let matches = regex.matches(in: string, options: [], range: range)
            return !matches.isEmpty
        } catch {
            print("Error creating regular expression: \(error)")
            return false
        }
    }

    /*
     Trả về:
        + danh sách quốc gia
        + danh sách nhóm hashtag
     */
    func getBaseInfo(notification: NSNotification) {
        if let response = notification.userInfo?["response"] as? URLResponse,
            let responseData = notification.userInfo?["responseData"] as? NSMutableData {
            if let url = response.url {
                if (url.absoluteString.elementsEqual(LINK_MAIN)) {
                    let data = responseData as Data
                    if let html = String(data: data, encoding: .utf8) {
                        parse(html: html)
                    }
                }
            }
        }
    }
    
    /*
     parse Html get data
     */
    func parse(html: String) {
        do {
            let document: Document = try SwiftSoup.parse(html)
            guard let body = document.body() else {
                return
            }
            let jsonString = try? body.getElementById("__NEXT_DATA__")?.html()
            guard let jsonData = jsonString?.data(using: .utf8)! else { return }
            let json = try? JSON(data: jsonData)
            let data = json?["props"]["pageProps"]["dehydratedState"]["queries"][0]["state"]["data"]
            print("--------- List country:")
            print(data?["country"])
            print("--------- Link group hashtag:")
            print(data?["industry"])
        } catch {
            print("Error get info trending tiktok: " + String(describing: error))
        }
    }
    
    /*
     Trả về:
     + danh sách header để call request lấy thông tin
     */
    func gatBaseRequest(notification: NSNotification) {
        if let request = notification.userInfo?["request"] as? URLRequest {
            if let url = request.url {
                if (isMatching(inString: url.absoluteString)) {
                    let headers = request.allHTTPHeaderFields
                    let timestamp = headers?["timestamp"]
                    let webId = headers?["web-id"]
                    let userSign = headers?["user-sign"]
                    let anonymousUserId = headers?["anonymous-user-id"]
                    print("------------- BaseRequest --------------")
                    print("Headers: ")
                    print(" timestamp: \(timestamp ?? "empty")")
                    print(" web-id: \(webId ?? "empty")")
                    print(" user-sign: \(userSign ?? "empty")")
                    print(" anonymous-user-id: \(userSign ?? "empty")")
                }
            }
        }
    }
}

extension ViewController {
    //Luồng chính thông tin
    @objc fileprivate func updateNetworkLog(notification: NSNotification) {
        getBaseInfo(notification: notification)
        gatBaseRequest(notification: notification)
        /*
         BaseRequest query thông tin trending được truyền header
         Header cần truyền với tất cả api trending dưới:
            timestamp: Lấy được từ gatBaseRequest
            user-sign: Lấy được từ gatBaseRequest
            web-id: Lấy được từ gatBaseRequest
         Video: => lấy xong gọi detail như lúc lấy link donwload hoặc review đẩy lấy ra lượt play
         https://ads.tiktok.com/creative_radar_api/v1/popular_trend/list?period=7&page=1&limit=10&order_by=like&country_code=VN
             các tham số:
                 page, limit: phân trang
                 country_code: truyền country lấy được từ getBaseInfo
         Track: => chờ code lấy lượt được sử dụng
         https://ads.tiktok.com/creative_radar_api/v1/popular_trend/sound/rank_list?period=7&page=1&limit=20&rank_type=popular&new_on_board=false&commercial_music=false&country_code=VN
             các tham số:
                 page, limit: phân trang
                 country_code: truyền country lấy được từ getBaseInfo
         HashTag: => call hết nhóm để trả về
         https://ads.tiktok.com/creative_radar_api/v1/popular_trend/hashtag/list?page=1&limit=20&period=7&industry_id=22000000000&country_code=VN&sort_by=popular
            các tham số:
                page, limit: phân trang
                country_code: truyền country lấy được từ getBaseInfo
                industry_id: truyền group hashtag lấy được từ getBaseInfo
         */
    }
}
