//
//  UpdateCheck.swift
//  InjectionIII
//
//  Created by John Holdsworth on 17/09/2020.
//  Copyright © 2020 John Holdsworth. All rights reserved.
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
                         30 * 24 * 60 * 60, forKey: updateCheckKey)
        }
    }
}

struct Release: Codable {
    let url: URL
    let assetsUrl: URL
    let uploadUrl: String
    let htmlUrl: URL
    let id: Int
    let nodeId: String
    let tagName: String?
    let targetCommitish: String
    let name: String
    let draft: Bool
    let author: Author
    let prerelease: Bool
    let createdAt: Date
    let publishedAt: Date
    let assets: [Asset]
    let tarballUrl: URL
    let zipballUrl: URL
    let body: String
}

struct Author: Codable {
    let login: String
    let id: Int
    let nodeId: String
    let avatarUrl: URL
    let gravatarId: String
    let url: URL
    let htmlUrl: URL
    let followersUrl: URL
    let followingUrl: String
    let gistsUrl: String
    let starredUrl: String
    let subscriptionsUrl: URL
    let organizationsUrl: URL
    let reposUrl: URL
    let eventsUrl: String
    let receivedEventsUrl: URL
    let type: String
    let siteAdmin: Bool
}

struct Asset: Codable {
    let url: URL
    let id: Int
    let nodeId: String
    let name: String
    let label: String?
    let uploader: Author
    let contentType: String
    let state: String
    let size: Int
    let downloadCount: Int
    let createdAt: Date
    let updatedAt: Date
    let browserDownloadUrl: URL
}



