import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Google Maps
    // Read API key from Info.plist
    if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
       let dict = NSDictionary(contentsOfFile: path),
       let apiKey = dict["GMSApiKey"] as? String {
      GMSServices.provideAPIKey(apiKey)
    } else {
      // Fallback to direct key if Info.plist reading fails
      GMSServices.provideAPIKey("AIzaSyBb1IGpqLzKwdtAfyzsqP7YZpn0nQI9iQo")
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
