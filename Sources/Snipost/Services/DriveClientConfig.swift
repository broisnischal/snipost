import Foundation

/// The app's own Google OAuth client, shipped with the app so end users only
/// ever see a "Connect Google Drive" button (the Xnapper/CleanShot model).
///
/// Create it once as the developer: console.cloud.google.com → new project →
/// enable "Google Drive API" → OAuth consent screen (External, publish) →
/// Credentials → Create credentials → OAuth client ID → **Desktop app**.
/// Then either fill the constants below, or drop a `DriveClient.plist` with
/// string keys `ClientID` / `ClientSecret` into `Resources/` (gitignored;
/// make-app.sh bundles it). For installed apps Google explicitly treats the
/// client secret as non-confidential, so embedding it is standard practice.
enum DriveClientConfig {
    static let embeddedClientID = ""
    static let embeddedClientSecret = ""

    static let bundled: (id: String, secret: String)? = {
        for url in candidatePlists {
            guard let data = try? Data(contentsOf: url),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
                  let dict = plist as? [String: String],
                  let id = dict["ClientID"], !id.isEmpty,
                  let secret = dict["ClientSecret"]
            else { continue }
            return (id, secret)
        }
        if !embeddedClientID.isEmpty {
            return (embeddedClientID, embeddedClientSecret)
        }
        return nil
    }()

    private static var candidatePlists: [URL] {
        var urls: [URL] = []
        if let bundledURL = Bundle.main.url(forResource: "DriveClient", withExtension: "plist") {
            urls.append(bundledURL)
        }
        // Dev runs (`swift run`) have no bundle — look next to the sources too.
        urls.append(URL(fileURLWithPath: "Resources/DriveClient.plist"))
        return urls
    }
}
