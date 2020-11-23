//
//  UpdateCheck.swift
//  InjectionIII
//
//  Created by John Holdsworth on 17/09/2020.
//  Copyright © 2020 John Holdsworth. All rights reserved.
//
//  $Id: //depot/ResidentEval/InjectionIII/UpdateCheck.swift#5 $
//

import Foundation

extension AppDelegate {

    @IBAction func updateCheck(_ sender: NSMenuItem?) {

        URLSession(configuration: .default).dataTask(with: URL(string:
            "https://api.github.com/repos/johnno1962/InjectionIII/releases")!) {
                data, response, error in
            do {
                if let data = data {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    decoder.dateDecodingStrategy = .iso8601
                    let releases = try decoder.decode([Release].self, from: data)

                    DispatchQueue.main.async {
                        guard let latest = releases
                            .first(where: { !$0.prerelease }),
                            let available = latest.tagName,
                            let current = Bundle.main.object(
                                forInfoDictionaryKey: "CFBundleShortVersionString")
                                as? String,
                            available.compare(current, options: .numeric)
                                == .orderedDescending else {
                            if sender != nil {
                                let alert = NSAlert()
                                alert.addButton(withTitle: "OK")
                                alert.addButton(withTitle: "Check Monthly")
                                alert.messageText = "You are running the latest released version."
                                switch alert.runModal() {
                                case .alertSecondButtonReturn:
                                    self.updateItem.state = .on
                                default:
                                    break
                                }
                            }
                            self.setUpdateCheck()
                            return
                        }

                        let fmt = DateFormatter()
                        fmt.dateStyle = .medium
                        let alert = NSAlert()
                        alert.messageText = "New build \(available) (\(fmt.string(from: latest.publishedAt))) is available."
                        alert.informativeText = latest.body
                        alert.addButton(withTitle: "View")
                        alert.addButton(withTitle: "Download")
                        alert.addButton(withTitle: "Later")
                        switch alert.runModal() {
                        case .alertFirstButtonReturn:
                            NSWorkspace.shared.open(latest.htmlUrl)
                        case .alertSecondButtonReturn:
                            NSWorkspace.shared.open(latest
                                .assets[0].browserDownloadUrl)
                        default:
                            break
                        }
                        self.setUpdateCheck()
                    }
                }
                else if let error = error {
                    throw error
                }
            } catch {
                DispatchQueue.main.async {
                    NSAlert(error: error).runModal()
                }
            }
        }.resume()
    }

    func setUpdateCheck() {
        if updateItem.state == .on {
            defaults.set(Date.timeIntervalSinceReferenceDate +
                         30 * 24 * 60 * 60, forKey: UserDefaultsUpdateCheck)
        }
    }

    struct Release: Decodable {
        let htmlUrl: URL
        let tagName: String?
        let prerelease: Bool
        let publishedAt: Date
        let assets: [Asset]
        let body: String
    }

    struct Asset: Decodable {
        let browserDownloadUrl: URL
    }
}
