import UIKit
import CoreLocation
import MapKit
import Foundation

class ViewController: UIViewController, CLLocationManagerDelegate, UITextFieldDelegate, MKMapViewDelegate {

    @IBOutlet weak var destinationStopNumber: UITextField!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var showCurrBtn: UIButton!
    @IBOutlet weak var destinationCtrlBtn: UIButton!
    @IBOutlet weak var goBtn: UIButton!
    
    var locationManager_ : CLLocationManager = CLLocationManager()
    var currentLocation_ : CLLocation?
    // Set to true when need map to centre on current location, then stop centerring. An example is when right after launching the app.
    var showCurrent_ = true
    var trackMode_ = false
    var destinationLocation_ : CLLocation?
    var monitorRadius_: Double = 500 // must be smaller than locationManager_.maximumRegionMonitoringDistance
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager_.desiredAccuracy = kCLLocationAccuracyBest
        locationManager_.delegate = self
        
        locationManager_.requestAlwaysAuthorization()
        
        destinationStopNumber.delegate = self
        // Set the keyboard to numbers only with a "Done" button.
        destinationStopNumber.keyboardType = UIKeyboardType.numberPad
        addNumberPadToolbar()
        
        self.mapView.delegate = self
        mapView.showsUserLocation = true
        
        destinationCtrlBtn.isEnabled = false
        goBtn.isEnabled = false // disable GO button on startup since no destination has been set
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {
            showAlert(title: "No Region Tracking", message: "Tracking not supported on this device. Check if Background App Refresh is on and Airplane mode is off.")
        }
    }
    
    
    // MARK: CLLocationManager delegates
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation_ = locations.last!
        
        if showCurrent_ {
            // In this case we only want to the map to centre on current location once, then stop centerring.
            showCurrent_ = false
            animateMap(currentLocation_!)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        let alertController = UIAlertController(title: "Invalid coordinates",
                                                message: "Monitoring failed for region with identifier: \(region!.identifier)",
                                                preferredStyle: .alert)
        let OKAction = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(OKAction)
        self.present(alertController, animated: true, completion:nil)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let alertController = UIAlertController(title: "Invalid coordinates",
                                                message: "Location Manager failed with the following error: \(error)",
            preferredStyle: .alert)
        let OKAction = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(OKAction)
        self.present(alertController, animated: true, completion:nil)
    }
    
    // Called when authorization status changes, or if authorization is already granted, called after location manager is intialized
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        // If location service is enabled, we can show user location.
        mapView.showsUserLocation = (status == .authorizedAlways)
        
        if (CLLocationManager.authorizationStatus() == .authorizedAlways) {
            locationManager_.startUpdatingLocation()
            DispatchQueue.main.async {
                self.showCurrBtn.isEnabled = true
            }
            
            showCurrent_ = true
        }
        else {
            showAlert(title: "No GPS Data", message: "Please enable location service for this app in the Settings.")
            DispatchQueue.main.async {
                self.showCurrBtn.isEnabled = false
                self.destinationCtrlBtn.isEnabled = false
                self.goBtn.isEnabled = false
            }
        }
    }
    
    
    // MARK: MKMapView delegates
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKCircle {
            let circleRenderer = MKCircleRenderer(overlay: overlay)
            circleRenderer.lineWidth = 1.0
            circleRenderer.strokeColor = .blue
            circleRenderer.fillColor = UIColor.green.withAlphaComponent(0.1)
            return circleRenderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
    
    
    // MARK: Actions
    @IBAction func showDestination(_ sender: UIButton) {
        animateMap(destinationLocation_!, diameter: monitorRadius_ * 2)
    }
    
    @IBAction func startJourney(_ sender: UIButton) {
        animateMap(currentLocation_!)
        
        if (sender.currentTitle! == "GO") {
            startMonitoring()
        }
        else {
            stopMonitoring()
        }
    }
    
    @IBAction func showCurrentLocation(_ sender: UIButton) {
        animateMap(currentLocation_!)
    }
    
    
    // MARK: UITextField delegates
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool
    {
        let allowedCharacters = CharacterSet.decimalDigits
        let characterSet = CharacterSet(charactersIn: string)
        return allowedCharacters.isSuperset(of: characterSet)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Hide the keyboard.
        textField.resignFirstResponder()
        return true
    }
    
    
    // MARK: Helper
    
    func animateMap(_ location: CLLocation, diameter: Double = 1000) {
        let region = MKCoordinateRegionMakeWithDistance(location.coordinate, diameter, diameter)
        mapView.setRegion(region, animated: true)
    }
    
    func startMonitoring() {
        let region = CLCircularRegion(center: destinationLocation_!.coordinate, radius: CLLocationDistance(monitorRadius_), identifier: "destination")
        // Only notify user when they have entered the region, but not when the exit. 
        // Scenerio: User sets their current location as their destination to monitor when they have returned to the starting point.
        // In this case, user should not be concerned with knowing when they have left region centred on the starting point.
        region.notifyOnEntry = true
        region.notifyOnExit = false
        locationManager_.startMonitoring(for: region)
        
        addDestinationCircleOverlay()
        
        // Modify UI to indicate to the user that monitoring is on.
        goBtn.setTitle("STOP", for: .normal)
    }
    
    func stopMonitoring() {
        for region in locationManager_.monitoredRegions {
            guard let circularRegion = region as? CLCircularRegion, circularRegion.identifier == "destination" else { continue }
            locationManager_.stopMonitoring(for: circularRegion)
        }
        
        removeDestinationCircleOverlay()
        
        goBtn.setTitle("GO", for: .normal)
    }
    
    func addDestinationCircleOverlay() {
        mapView?.add(MKCircle(center: destinationLocation_!.coordinate, radius: CLLocationDistance(monitorRadius_)))
    }
    
    func removeDestinationCircleOverlay() {
        guard let overlays = mapView?.overlays else { return }
        mapView.removeOverlays(overlays)
    }
    
    enum DestCoordRESTResult<CLLocation> {
        case success(CLLocation)
        case failure(String)
    }
    
    func getDestinationCoords(completion: @escaping (DestCoordRESTResult<CLLocation>)->Void ) {
        guard let destinationStopNumberValue = Int(destinationStopNumber.text!) else {
            completion(DestCoordRESTResult.failure("Please enter valid stop number."))
            return
        }
        
        let endpoint: String = "http://api.translink.ca/rttiapi/v1/stops/"+String(destinationStopNumberValue)+"?apikey="+retrieveApiKey(keyName: "TRANSLINK_API_KEY")
        
        guard let url = URL(string: endpoint) else {
            completion(DestCoordRESTResult.failure("Could not create request from stop number."))
            return
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("application/JSON", forHTTPHeaderField: "accept")
        let session = URLSession.shared
        
        let task = session.dataTask(with: urlRequest) { (data, response, error) -> Void in
            // Check for errors.
            guard error == nil else {
                DispatchQueue.main.async {
                    completion(DestCoordRESTResult.failure("Error sending request."))
                }
                return
            }
            // Make sure data is present.
            guard let responseData = data else {
                DispatchQueue.main.async {
                    completion(DestCoordRESTResult.failure("Did not receive any data."))
                }
                return
            }
            
            do {
                // Parse response as JSON.
                guard let stopInfo = try JSONSerialization.jsonObject(with: responseData, options: [])
                    as? [String: Any] else {
                        completion(DestCoordRESTResult.failure("error trying to convert data to JSON."))
                        return
                }
                
                if stopInfo["Message"] != nil {
                    let errorMsg = stopInfo["Message"] as! String
                    completion(DestCoordRESTResult.failure(errorMsg))
                    return
                }
                
                guard let stopLatitude = stopInfo["Latitude"] as? Double else {
                    completion(DestCoordRESTResult.failure("Could not get latitude from JSON."))
                    return
                }
                guard let stopLongitude = stopInfo["Longitude"] as? Double else {
                    completion(DestCoordRESTResult.failure("Could not get latitude from JSON."))
                    return
                }
                
                let returnval = CLLocation(latitude: stopLatitude, longitude: stopLongitude)
                completion(DestCoordRESTResult.success(returnval))
            } catch {
                completion(DestCoordRESTResult.failure("Failed retrieving JSON data."))
            }
        }
        task.resume()
    }
    
    func addNumberPadToolbar() {
        let toolbar: UIToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 50))
        toolbar.barStyle       = UIBarStyle.default
        let flexSpace              = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: nil, action: nil)
        let search: UIBarButtonItem  = UIBarButtonItem(title: "Search", style: UIBarButtonItemStyle.done, target: self, action: #selector(ViewController.searchButtonAction))
        let cancel: UIBarButtonItem  = UIBarButtonItem(title: "Cancel", style: UIBarButtonItemStyle.plain, target: self, action: #selector(ViewController.cancelButtonAction))
        
        var items = [UIBarButtonItem]()
        items.append(cancel)
        items.append(flexSpace)
        items.append(search)
        
        toolbar.items = items
        toolbar.sizeToFit()
        
        destinationStopNumber.inputAccessoryView = toolbar
    }
    
    func cancelButtonAction() {
        destinationStopNumber.resignFirstResponder()
    }
    
    func searchButtonAction() {
        destinationStopNumber.resignFirstResponder()
        
        getDestinationCoords(completion: { result in
            switch result {
            case.failure(let errorMsg):
                self.showAlert(title: "Error Processing Stop Number", message: errorMsg)
            case.success(let returnedLocation):
                self.destinationLocation_ = returnedLocation
                if (self.destinationLocation_ == nil) {
                    self.showAlert(title: "Error Processing Stop Number", message: "Stop has no valid coordinates.")
                    return
                }
                
                DispatchQueue.main.async {
                    if (self.destinationCtrlBtn.isEnabled == false) {
                        self.destinationCtrlBtn.isEnabled = true
                    }
                    
                    if (self.goBtn.isEnabled == false) {
                        self.goBtn.isEnabled = true
                    }
                }
                
                // Remove all current pins
                self.mapView.removeAnnotations(self.mapView.annotations)
                
                // Add a pin to destination
                let targetPin = MKPointAnnotation()
                targetPin.coordinate = CLLocationCoordinate2DMake((self.destinationLocation_?.coordinate.latitude)!,
                                                                  (self.destinationLocation_?.coordinate.longitude)!)
                self.mapView.addAnnotation(targetPin)
                self.mapView.showAnnotations([targetPin], animated: true)
            }
        })
    }
    
    // This function is used to show a message pop-up to the user. The pop-up will only have an OK button.
    // Should be typically used for displaying errors.
    func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let OKAction = UIAlertAction(title: "OK", style: .cancel)
        alertController.addAction(OKAction)
        self.present(alertController, animated: true, completion:nil)
    }
    
    func retrieveApiKey(keyName:String) -> String {
        let filePath = Bundle.main.path(forResource: "ApiKeys", ofType: "plist")
        let keys = NSDictionary(contentsOfFile: filePath!)
        let value = keys?.object(forKey: keyName) as! String
        return value
    }
}

