//
//  FirstViewController.swift
//  TemplateProject
//
//  Created by ALAA AL MUTAWA on 8/10/15.
//  Copyright (c) 2015 Make School. All rights reserved.
//

import UIKit
import GoogleMaps
import MapKit
import ParseUI
import CoreLocation

class FirstViewController: UIViewController, UISearchBarDelegate, MKMapViewDelegate {
    var parseLoginHelper: ParseLoginHelper!
    var window: UIWindow?
    var searchController:UISearchController!
    @IBAction func showSearchBar(sender: AnyObject) {
        // Create the search controller and make it perform the results updating.
        searchController = UISearchController(searchResultsController: searchController)
        searchController.hidesNavigationBarDuringPresentation = false
        self.searchController.searchBar.delegate = self
        searchController.searchBar.placeholder = "Try 'restaurant, coffee, food, chinese, halal, etc..'"
        // Present the view controller
        presentViewController(searchController, animated: true, completion: nil)
    }
    var businesses: [Business]!
    func searchForPlace(searchtext: String, userLocation: MKUserLocation!){
        Business.searchWithTerm(userLocation, term: searchtext, sort: .Distance, categories: [], deals: true) { (businesses: [Business]!, error: NSError!) -> Void in
            self.businesses = businesses
            
            for business in businesses {
                var point = MKPointAnnotation()
                point.title = business.name
                point.subtitle = business.address
                point.coordinate = business.coordinate
                self.mapView.addAnnotation(point)
            }
        }
    }
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        let annotationsToRemove = mapView.annotations.filter { $0 !== self.mapView.userLocation }
        mapView.removeAnnotations( annotationsToRemove )
        searchForPlace(searchText, userLocation: mapView.userLocation)
    }

    
    
    @IBAction func writeMessage(sender: AnyObject) {
        let user = User.currentUser()
        let startViewController: UIViewController;
        if (user != nil) {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            startViewController = storyboard.instantiateViewControllerWithIdentifier("friends") as! UIViewController
            self.window = UIWindow(frame: UIScreen.mainScreen().bounds)
            self.window?.rootViewController = startViewController;
            self.window?.makeKeyAndVisible()
        } else {
            let alertController = UIAlertController(title: "You must login", message: "You need to login to message your friends", preferredStyle: .Alert)
            alertController.addAction(UIAlertAction(title: "No, thanks.", style: .Cancel, handler: nil))
            //PFFacebookUtils.initializeFacebookWithApplicationLaunchOptions(launchOptions)
            let loginViewController = LoginViewController()
            loginViewController.fields = .Facebook
            loginViewController.facebookPermissions = ["user_friends"]
            loginViewController.delegate = self.parseLoginHelper
            loginViewController.signUpController?.delegate = self.parseLoginHelper
            startViewController = loginViewController

            let loginHandler = { (action:UIAlertAction!) -> Void in
                self.presentViewController(loginViewController, animated: true, completion: nil)
                //self.window = UIWindow(frame: UIScreen.mainScreen().bounds)
                self.window?.rootViewController = startViewController;
                self.window?.makeKeyAndVisible()
            }
            alertController.addAction(UIAlertAction(title: "Ok, log me in", style: .Default, handler: loginHandler))
                self.presentViewController(alertController, animated: true, completion: nil)
        }
    }
    
   
      @IBOutlet weak var mapView: MKMapView!

    override func viewDidLoad() {
        super.viewDidLoad()
        if Reachability.isConnectedToNetwork(){
            parseLoginHelper = ParseLoginHelper {[unowned self] user, error in
                if let error = error {
                    ErrorHandling.defaultErrorHandler(error)
                    return
                }
                NSNotificationCenter.defaultCenter().postNotificationName(AppDelegate.Constants.DidLoginNotification, object: self)
                self.dismissViewControllerAnimated(true, completion: nil)
            }
            mapView.showsUserLocation = true;
            mapView.delegate = self;
            
            var press: UILongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: "action:")
            press.minimumPressDuration = 0.09
            mapView.addGestureRecognizer(press)
        }
        else{
            var alert: UIAlertView = UIAlertView(title: "Internet failure", message: "Please try again later, we are unable to connect to the server.", delegate: nil, cancelButtonTitle: "Ok");
            alert.show();

        }

    }
    
    func mapView(mapView: MKMapView!, didUpdateUserLocation userLocation: MKUserLocation!) {
       println(mapView.annotations.count)
        if mapView.annotations.count == 1{
            var viewRegion = MKCoordinateRegionMakeWithDistance(userLocation.coordinate, 1900, 1900);
            var adjustedRegion = mapView.regionThatFits(viewRegion)
            mapView.setRegion(adjustedRegion, animated: true);
        }
        
    }
    
    var touchMapCoordinate: CLLocationCoordinate2D?
    
    
    
    func action (rec: UILongPressGestureRecognizer){
        if rec.state == .Ended {
            let annotationsToRemove = mapView.annotations.filter { $0 !== self.mapView.userLocation }
            mapView.removeAnnotations( annotationsToRemove )
            var touchPoint : CGPoint  =  rec.locationInView(mapView)
            touchMapCoordinate = mapView.convertPoint(touchPoint, toCoordinateFromView: mapView)
            var pa = MKPointAnnotation()
            pa.coordinate = touchMapCoordinate!;
            var placemark = MKPlacemark(coordinate: pa.coordinate, addressDictionary: nil)
            pa.title = "Selected place";
            mapView.addAnnotation(pa)
            let geoCoder = CLGeocoder()
            let location = CLLocation(latitude: pa.coordinate.latitude, longitude: pa.coordinate.longitude)
            geoCoder.reverseGeocodeLocation(location, completionHandler: { (placemarks, error) -> Void in
                let placeArray = placemarks as? [CLPlacemark]
                var placeMark: CLPlacemark!
                placeMark = placeArray?[0]
                var sub: String = ""
                // Address dictionary
                
                // Location name
                if let locationName = placeMark.addressDictionary["Name"] as? String {
                    sub += locationName
                }
                if let city = placeMark.addressDictionary["City"] as? String {
                    sub += ", " + city
                }
                pa.subtitle = sub
                self.address = pa.subtitle
            })
            mapView.selectAnnotation(pa, animated: true)
        }
    }
    
    var address: String?
    var poly: MKPolyline!
    var t: Bool = false
    @IBAction func direct(sender: AnyObject) {
        if (mapView.annotations.count == 2){
            getDirection()
        }
        else{
            var alert: UIAlertView = UIAlertView(title: "Getting directions", message: "Please select a place to get directions to by placing a pin on the map.", delegate: nil, cancelButtonTitle: "Ok");
            alert.show();
        }
    }
    
    @IBOutlet weak var directions: UIBarButtonItem!
    
    
    func getDirection(){
        var alert: UIAlertView = UIAlertView(title: "Getting directions", message: "Please wait, this will take a few seconds...", delegate: nil, cancelButtonTitle: "Cancel");
        var loadingIndicator: UIActivityIndicatorView = UIActivityIndicatorView(frame: CGRectMake(50, 10, 37, 37)) as UIActivityIndicatorView
        loadingIndicator.center = self.view.center;
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.Gray
        loadingIndicator.startAnimating();
        
        alert.setValue(loadingIndicator, forKey: "accessoryView")
        loadingIndicator.startAnimating()
        alert.show();
        var myDestination = MKPlacemark(coordinate: touchMapCoordinate!, addressDictionary: nil)
        
        let destMKMap = MKMapItem(placemark: myDestination)!
        
        var directionRequest:MKDirectionsRequest = MKDirectionsRequest()
        directionRequest.setSource(MKMapItem.mapItemForCurrentLocation())
        directionRequest.setDestination(destMKMap)
        directionRequest.transportType = MKDirectionsTransportType.Walking
        
        
        let dir = MKDirections(request: directionRequest)
        dir.calculateDirectionsWithCompletionHandler() {
            (response:MKDirectionsResponse!, error:NSError!) in
            if response == nil {
                println(error)
                return
            }
            
            self.showRoute(response)
            let route = response.routes[0] as! MKRoute
            self.poly = route.polyline
            var msg: String = ""
            for step in route.steps {
                if (msg == ""){
                    msg += "After \(step.distance) metres: \(step.instructions)"
                    
                }
                else {
                    msg += "\nAfter \(step.distance) metres: \(step.instructions)"
                }
            }
            let alertController = UIAlertController(title: "Get directions", message: msg, preferredStyle: .Alert)
            
            alertController.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
            alert.dismissWithClickedButtonIndex(0, animated: true)
            self.presentViewController(alertController, animated: true, completion: nil)
            
        }
    }
    
    func showRoute(response: MKDirectionsResponse) {
        for route in response.routes as! [MKRoute] {
            mapView.addOverlay(route.polyline,
                level: MKOverlayLevel.AboveRoads)
        }
        let userLocation = mapView.userLocation
        let region = MKCoordinateRegionMakeWithDistance(
            userLocation.location.coordinate, 2000, 2000)
        mapView.setRegion(region, animated: true)
    }
    
    func mapView(mapView: MKMapView!, rendererForOverlay
        overlay: MKOverlay!) -> MKOverlayRenderer! {
            self.mapView.removeOverlay(self.poly)
            var renderer : MKPolylineRenderer! = nil
            if let overlay = overlay as? MKPolyline {
            renderer = MKPolylineRenderer(overlay: overlay)
            renderer.strokeColor = UIColor.blueColor().colorWithAlphaComponent(0.8)
            renderer.lineWidth = 5.0
            }
            return renderer
    }
    
    var message : String?
    
    func mapView(mapView: MKMapView!, annotationView view: MKAnnotationView!, calloutAccessoryControlTapped control: UIControl!) {

        
        let getFriendsActionHandler = { (action: UIAlertAction!) -> Void in
            if (User.currentUser() != nil){
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let startViewController = storyboard.instantiateViewControllerWithIdentifier("friendsPicker") as! UINavigationController
                self.presentViewControllerFromTopViewController(startViewController, animated: true, completion: nil)
                let com = startViewController.visibleViewController as! FriendPickerViewController
                com.selectedLocation = self.touchMapCoordinate
                com.address = self.address
                // var viewCont = startViewController.viewControllers[0] as! SendRequestViewController //IS THIS EVEN POSSIBLE OR RIGHT?
                //viewCont.selectedLocation = self.touchMapCoordinate
                //self.window = UIWindow(frame: UIScreen.mainScreen().bounds)
                self.window?.rootViewController = startViewController
            }
            else{

                let alertController = UIAlertController(title: "You must login", message: "You need to login to access your friends list", preferredStyle: .Alert)
                alertController.addAction(UIAlertAction(title: "No, thanks.", style: .Cancel, handler: nil))
                let startViewController: UIViewController;
                //PFFacebookUtils.initializeFacebookWithApplicationLaunchOptions(launchOptions)
                let loginViewController = LoginViewController()
                loginViewController.fields = .Facebook
                loginViewController.facebookPermissions = ["user_friends"]
                loginViewController.delegate = self.parseLoginHelper
                loginViewController.signUpController?.delegate = self.parseLoginHelper
                startViewController = loginViewController
                
                let loginHandler = { (action:UIAlertAction!) -> Void in
                    self.presentViewController(loginViewController, animated: true, completion: nil)
                    //self.window = UIWindow(frame: UIScreen.mainScreen().bounds)
                    self.window?.rootViewController = startViewController;
                    self.window?.makeKeyAndVisible()
                }
                alertController.addAction(UIAlertAction(title: "Ok, log me in", style: .Default, handler: loginHandler))
                self.presentViewController(alertController, animated: true, completion: nil)
            }


            }
            
        
            let alertMessage = UIAlertController(title: "Which friend?", message: "You need to pick a friend to meet in this location", preferredStyle: .Alert)
            //self.touchMapCoordinate = view.annotation.coordinate
            
            alertMessage.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
            alertMessage.addAction(UIAlertAction(title: "Ok, let me pick", style: .Default, handler: getFriendsActionHandler))
            self.presentViewController(alertMessage, animated: true, completion: nil)
    
//        alertController.addAction(requestAction)
//        self.presentViewController(alertController, animated: true, completion: nil)
    }

    
    
    func mapView(mapView: MKMapView!, didSelectAnnotationView view: MKAnnotationView!) {
        var rec : UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: "actions:")
        mapView.addGestureRecognizer(rec)
    }
    
    func actions(gest: UITapGestureRecognizer){
        
        let getFriendsActionHandler = { (action: UIAlertAction!) -> Void in
            if (User.currentUser() != nil){
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let startViewController = storyboard.instantiateViewControllerWithIdentifier("friendsPicker") as! UINavigationController
                self.presentViewControllerFromTopViewController(startViewController, animated: true, completion: nil)
                let com = startViewController.visibleViewController as! FriendPickerViewController
                com.selectedLocation = self.touchMapCoordinate
                com.address = self.address
                // var viewCont = startViewController.viewControllers[0] as! SendRequestViewController //IS THIS EVEN POSSIBLE OR RIGHT?
                //viewCont.selectedLocation = self.touchMapCoordinate
                //self.window = UIWindow(frame: UIScreen.mainScreen().bounds)
                self.window?.rootViewController = startViewController
            }
            else{
                
                let alertController = UIAlertController(title: "You must login", message: "You need to login to access your friends list", preferredStyle: .Alert)
                alertController.addAction(UIAlertAction(title: "No, thanks.", style: .Cancel, handler: nil))
                let startViewController: UIViewController;
                //PFFacebookUtils.initializeFacebookWithApplicationLaunchOptions(launchOptions)
                let loginViewController = LoginViewController()
                loginViewController.fields = .Facebook
                loginViewController.facebookPermissions = ["user_friends"]
                loginViewController.delegate = self.parseLoginHelper
                loginViewController.signUpController?.delegate = self.parseLoginHelper
                startViewController = loginViewController
                
                let loginHandler = { (action:UIAlertAction!) -> Void in
                    self.presentViewController(loginViewController, animated: true, completion: nil)
                    //self.window = UIWindow(frame: UIScreen.mainScreen().bounds)
                    self.window?.rootViewController = startViewController;
                    self.window?.makeKeyAndVisible()
                }
                alertController.addAction(UIAlertAction(title: "Ok, log me in", style: .Default, handler: loginHandler))
                self.presentViewController(alertController, animated: true, completion: nil)
            }
            
            
        }
        
        
        let alertMessage = UIAlertController(title: "Which friend?", message: "You need to pick a friend to meet in this location", preferredStyle: .Alert)
        //self.touchMapCoordinate = view.annotation.coordinate
        
        alertMessage.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
        alertMessage.addAction(UIAlertAction(title: "Ok, let me pick", style: .Default, handler: getFriendsActionHandler))
        self.presentViewController(alertMessage, animated: true, completion: nil)

    }
    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
        if let annotation = annotation as? MKUserLocation {
            return nil
        }
        
        var annotationView : MKAnnotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "loc")
     
        
        annotationView.draggable = true
        annotationView.canShowCallout = true
       
        
        
        let deleteButton = UIButton.buttonWithType(UIButtonType.Custom) as! UIButton
        deleteButton.frame.size.width = 44
        deleteButton.frame.size.height = 44
        deleteButton.backgroundColor = UIColor.clearColor()
        deleteButton.setImage(UIImage(named: "send12-3.png"), forState: .Normal)
        
       annotationView.rightCalloutAccessoryView = deleteButton
        
  
                return annotationView
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}