//
//  VolumeControlVC.swift
//  Sonos_Volume_Control
//
//  Created by Alexander Heinrich on 06.03.18.
//  Copyright © 2018 Sn0wfreeze Development UG. All rights reserved.
//

import Cocoa
import SWXMLHash

class ControlVC: NSViewController {

    //MARK: Properties
    @IBOutlet weak var sonosStack: NSStackView!
    @IBOutlet weak var volumeSlider: NSSlider!
    @IBOutlet weak var errorMessageLabel: NSTextField!
    @IBOutlet weak var controlsView: NSView!
    @IBOutlet weak var pauseButton: PlayPauseButton!
    @IBOutlet weak var sonosScrollContainer: CustomScrolllView!
    @IBOutlet weak var speakerGroupSelector: NSSegmentedControl!
    @IBOutlet weak var currentTrackLabel: NSTextField!
    @IBOutlet weak var trackLabelLeading: NSLayoutConstraint!
    
    let defaultHeight: CGFloat = 143.0
    let defaultWidth:CGFloat = 228.0
    let maxHeight: CGFloat = 215.0
    
    private let discovery: SSDPDiscovery = SSDPDiscovery.defaultDiscovery
    fileprivate var session: SSDPDiscoverySession?
    
    var sonosSystems = [SonosController]()
    var sonosGroups: [String : SonosSpeakerGroup] = [:]
    var speakerButtons: [SonosController: NSButton] = [:]
    var lastDiscoveryDeviceList = [SonosController]()
    var devicesFoundCurrentSearch = 0
    
    var groupButtons: [SonosSpeakerGroup: NSButton] = [:]
    
    var activeGroup: SonosSpeakerGroup? {
        return self.sonosGroups.values.first(where: {$0.isActive})
    }
    
    var showState = ShowState.speakers
    
    var isAnimating = false
    
    //MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        if sonosSystems.count == 0 {
            errorMessageLabel.isHidden = false
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        searchForDevices()
        updateState()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        //Show Demo only in demo target
        if (Bundle.main.object(forInfoDictionaryKey: "CFBundleIdentifier") as? String) == "de.sn0wfreeze.Sonos-Volume-Control-Demo" {
            self.showDemo()
        }
        self.setupScrollView()
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        
        self.stopAnimations()
    }
    
    func addTest() {
        for i in 0..<2 {
            let testSonos = SonosController(roomName: "Room\(i)", deviceName: "PLAY:3", url: URL(string:"http://192.168.178.9\(i)")!, ip: "192.168.178.9\(i)", udn: "some-udn-\(i)")
            testSonos.playState = .playing
            self.addDeviceToList(sonos: testSonos)
            self.controlsView.isHidden = false
        }
    }
    
    func showDemo() {
        self.stopDiscovery()
        let t1 = SonosController(roomName: "Bedroom", deviceName: "PLAY:3", url: URL(string:"http://192.168.178.91")!, ip: "192.168.178.91", udn: "some-udn-1")
        t1.playState = .playing
        t1.deviceInfo = SonosDeviceInfo(zoneName: "Bedroom", localUID: "01")
        t1.groupState = SonosGroupState(name: "Bedroom", groupID: "01", deviceIds: ["01", "02"])
        self.addDeviceToList(sonos: t1)
        self.updateGroups(sonos: t1)
        
        let t2 = SonosController(roomName: "Bedroom", deviceName: "PLAY:1", url: URL(string:"http://192.168.178.92")!, ip: "192.168.178.92", udn: "some-udn-2")
        t2.playState = .playing
        t2.deviceInfo = SonosDeviceInfo(zoneName: "Bedroom", localUID: "02")
        t2.groupState = SonosGroupState(name: "Bedroom", groupID: "01", deviceIds: ["01", "02"])
        self.addDeviceToList(sonos: t2)
        self.updateGroups(sonos: t2)
        
        let t3 = SonosController(roomName: "Kitchen", deviceName: "PLAY:1", url: URL(string:"http://192.168.178.93")!, ip: "192.168.178.93", udn: "some-udn-3")
        t3.playState = .paused
        t3.deviceInfo = SonosDeviceInfo(zoneName: "Kitchen", localUID: "03")
        t3.groupState = SonosGroupState(name: "Kitchen", groupID: "03", deviceIds: ["03"])
        self.addDeviceToList(sonos: t3)
        self.updateGroups(sonos: t3)
        
        self.controlsView.isHidden = false
    }
    
    //MARK: - Updating Sonos Players
    /**
     Add a device to the list of devices
     
     - Parameters:
     - sonos: The Sonos Device which was found and should be added
     */
    func addDeviceToList(sonos: SonosController) {
        guard sonosSystems.contains(sonos) == false else {return}
        
        //New sonos system. Add it to the list
        sonos.delegate = self
        self.sonosSystems.append(sonos)
        
        if self.showState == .speakers {
            self.updateSonosDeviceList()
            
            if self.sonosSystems.count >= 1 {
                self.updateState()
            }
        }
    }
    
    func updateSonosDeviceList() {
        guard self.showState == .speakers else {return}
        //Remove error label
        if self.sonosSystems.count > 0 {
            self.errorMessageLabel.isHidden = true
        }
        
        //Remove all buttons
        for view in self.sonosStack.subviews {
            self.sonosStack.removeView(view)
        }
        
        self.sortSpeakers()
        
        //Add all sonos buttons
        for sonos in sonosSystems {
            let button = NSButton(checkboxWithTitle: sonos.readableName, target: sonos, action: #selector(SonosController.activateDeactivate(button:)))
            button.state = sonos.active ? .on : .off
            self.sonosStack.addArrangedSubview(button)
            self.speakerButtons[sonos] = button
        }
        
        self.setupScrollView()
    }
    
    /**
     Remove old devices which have not been discovered for 10 minutes
    */
    func removeOldDevices() {
        //Remove undiscovered devices
        //All devices which haven't been found on last discovery
        let undiscoveredDevices = self.sonosSystems.filter({self.lastDiscoveryDeviceList.contains($0) == false})
        for sonos in undiscoveredDevices {
            guard let button = self.speakerButtons[sonos],
                button.superview == self.sonosStack else {continue}
            // Remove all buttons of speakers which have not been discovered
            self.sonosStack.removeView(button)
            self.speakerButtons[sonos] = nil
        }
        
        self.sonosSystems = self.sonosSystems.filter({undiscoveredDevices.contains($0) == false})
    }
    
    /**
     Update the groups controllers
     
     - Parameters:
     - sonos: The Sonos speaker which should be added to the group
     */
    func updateGroups(sonos: SonosController) {
        guard let gId = sonos.groupState?.groupID else {return}
        
        if let group = self.sonosGroups[gId] {
            group.addSpeaker(sonos)
        }else {
            let group = SonosSpeakerGroup(groupID: gId,firstSpeaker: sonos)
            group.delegate = self
            self.sonosGroups[gId] = group
        }
        
        //Remove empty groups
        let containedInGroups = Array(self.sonosGroups.values.filter({$0.speakers.contains(sonos)}))
        for group in containedInGroups {
            //Check where speaker has moved to
            group.removeSpeaker(sonos)
            if group.speakers.count == 0 {
                //Remove group
                self.sonosGroups.removeValue(forKey: group.groupID)
            }
        }
        
        if self.showState == .groups {
            self.updateGroupsList()
            
            self.updateState()
        }
        
    }
    
    func updateGroupsList() {
        guard self.showState == .groups else {return}
        //Remove error label or show it if necessary
        if self.sonosSystems.count > 0 {
            self.errorMessageLabel.isHidden = true
        }else {
            self.errorMessageLabel.isHidden = false
        }
        
        //Remove all buttons
        for view in self.sonosStack.subviews {
            self.sonosStack.removeView(view)
        }
        
        var sonosGroupArray = Array(self.sonosGroups.values)
        
        sonosGroupArray.sort { (lhs, rhs) -> Bool in
            return  lhs.name < rhs.name
        }
        
        //Add all sonos buttons
        for (idx, group) in sonosGroupArray.enumerated() {
            if idx == 0 && self.activeGroup == nil {
                group.isActive = true
            }
            
            let button = NSButton(radioButtonWithTitle: group.name, target: group, action: #selector(SonosSpeakerGroup.activateDeactivate(button:)))
            button.state = group.isActive ? .on : .off
            self.sonosStack.addArrangedSubview(button)
            self.groupButtons[group] = button
        }
        
        self.setupScrollView()
    }
    
    /**
     Found a duplicate sonos. Check if the IP address has changed
     
     - Parameters:
        - idx: Index at which the equal sonos is placed in sonosSystems
        - sonos: The newly discovered sonos
     */
    func replaceSonos(atIndex idx: Int, withSonos sonos: SonosController) {
        let eqSonos = sonosSystems[idx]
        if eqSonos.ip != sonos.ip {
            //Ip address changes
            sonosSystems.remove(at: idx)
            sonosSystems.insert(sonos, at: idx)
            sonos.active = eqSonos.active
        }
    }
    
    func setupScrollView() {
       self.sonosScrollContainer.scrollToTop()
       self.sonosScrollContainer.isScrollingEnabled = self.sonosSystems.count > 4
    }
    
    func updateState() {
        switch self.showState {
        case .groups:
            self.updateStateForGroupMode()
        case .speakers:
            self.updateStateForSpeakerMode()
        }
    }
    
    func updateStateForGroupMode() {
        self.activeGroup?.getGroupVolume({ (volume) in
            self.volumeSlider.integerValue = volume
        })
        
        self.activeGroup?.getPlayState({ (state) in
            self.updatePlayButton(forState: state)
        })
    }
    
    func updateStateForSpeakerMode() {
        let firstSonos = sonosSystems.first(where: {$0.active})
        firstSonos?.getVolume({ (volume) in
            if firstSonos?.muted == true {
                self.volumeSlider.integerValue = 0
            }else {
                self.volumeSlider.integerValue = volume
            }
        })
        
        if firstSonos?.isGroupCoordinator == true {
            firstSonos?.getPlayState({ (state) in
                self.updatePlayButton(forState: state)
            })
        }else if let coordinator = sonosSystems.first(where: {$0.active && $0.isGroupCoordinator}) {
            coordinator.getPlayState({ (state) in
                self.updatePlayButton(forState: state)
            })
            
            coordinator.updateCurrentTrack({ (trackInfo) in
                self.updateTrackLabel(withTrack: trackInfo.trackText())
            })
        }else {
            //Hide buttons
            self.controlsView.isHidden = true
        }
    }
    
    func updateTrackLabel(withTrack track: String) {
        self.stopAnimations()
        self.currentTrackLabel.stringValue = track
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.animateTrackLabel()
        }

    }
    
    func animateTrackLabel() {
        guard self.currentTrackLabel.frame.width > self.view.frame.width, isAnimating == false else {return}
        
        self.isAnimating = true
        self.trackLabelLeading.constant = 8
        NSAnimationContext.runAnimationGroup({ (context) in
            context.duration = 10.0
            self.trackLabelLeading.animator().constant = -self.currentTrackLabel.frame.width
        }) {
            guard self.isAnimating else {return}
            self.trackLabelLeading.constant = self.currentTrackLabel.frame.width
            //Completed one way
            NSAnimationContext.runAnimationGroup({ (context) in
                context.duration = 10.0
                self.trackLabelLeading.animator().constant = 8
            }, completionHandler: {
                self.isAnimating = false
            })
        }
    }
    
    func stopAnimations() {
        self.isAnimating = false
        
        NSAnimationContext.runAnimationGroup({ (context) in
            context.duration = 0.1
            self.trackLabelLeading.animator().constant = 8
        }, completionHandler: nil)
    }
    
    func updatePlayButton(forState state: PlayState) {
        switch (state) {
        case .playing, .transitioning:
            self.pauseButton.currentState = .pause
            self.controlsView.isHidden = false
        case .paused, .stopped:
            self.pauseButton.currentState = .play
            self.controlsView.isHidden = false
        default:
            self.controlsView.isHidden = true
        }
    }
    
    //MARK: - Interactions
    
    @IBAction func switchSpeakerGroups(_ sender: Any) {
        let selected = self.speakerGroupSelector.indexOfSelectedItem
        if (selected == 0) {
            //Show speakers
            self.showState = .speakers
            self.updateSonosDeviceList()
        }else {
            //Show groups
            self.showState = .groups
            self.updateGroupsList()
        }
        self.updateState()
    }
    
    @IBAction func setVolume(_ sender: NSSlider) {
        switch self.showState {
        case .speakers:
            for sonos in sonosSystems {
                guard sonos.active else {continue}
                sonos.setVolume(volume: sender.integerValue)
            }
        case .groups:
            self.activeGroup?.setVolume(volume: sender.integerValue)
        }
        
    }
    
    @IBAction func playPause(_ sender: Any) {
        let actionState = self.pauseButton.currentState
        
        switch self.showState {
        case .speakers:
            for sonos in sonosSystems {
                guard sonos.active else {continue}
                self.playPause(forSonos: sonos, actionState: actionState)
            }
            
        case .groups:
            switch actionState {
            case .play:
                self.activeGroup?.play()
                self.updatePlayButton(forState: .playing)
            case .pause:
                self.activeGroup?.pause()
                self.updatePlayButton(forState: .paused)
            }
        }
        
    }
    
    private func playPause(forSonos sonos: SonosController, actionState: PlayPauseButton.State) {
        //Play or pause based on the button state
        switch actionState {
        case .pause:
            sonos.pause()
        case .play:
            sonos.play()
        }
        self.updatePlayButton(forState: sonos.playState)
    }
    
    private func pause(sonos: SonosController) {
        
    }
    
    private func play(sonos: SonosController) {
        
    }
    
    @IBAction func nextTrack(_ sender: Any) {
        switch self.showState {
        case .speakers:
            for sonos in sonosSystems {
                guard sonos.active else {continue}
                sonos.next()
            }
        case .groups:
            self.activeGroup?.next()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.updateState()
        }
        
    }
    
    @IBAction func prevTrack(_ sender: Any) {
        switch self.showState {
        case .speakers:
            for sonos in sonosSystems {
                guard sonos.active else {continue}
                sonos.previous()
            }
        case .groups:
            self.activeGroup?.previous()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.updateState()
        }
    }
    
    @IBAction func showMenu(_ sender: NSView) {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Send Feedback", action: #selector(sendFeedback), keyEquivalent: "")
        appMenu.addItem(withTitle: "Show Imprint", action: #selector(openImprint), keyEquivalent: "")
        appMenu.addItem(withTitle: "Software licenses", action: #selector(openLicenses), keyEquivalent: "")
        appMenu.addItem(withTitle: "Quit", action: #selector(quitApp), keyEquivalent: "")
        
        
        let p = NSPoint(x: sender.frame.origin.x, y: sender.frame.origin.y - (sender.frame.height / 2))
        appMenu.popUp(positioning: nil, at: p, in: sender.superview)
    }
    
    @objc func quitApp() {
        NSApp.terminate(self)
    }
    
    @objc func openImprint() {
        NSWorkspace.shared.open(URL(string:"http://sn0wfreeze.de/?p=522")!)
    }
    
    @objc func openLicenses() {
        NSWorkspace.shared.open(URL(string:"http://sn0wfreeze.de/?p=525")!)
    }
    
    @objc func sendFeedback() {
        NSWorkspace.shared.open(URL(string:"mailto:sonos-controller@sn0wfreeze.de")!)
    }
    
}

//MARK: - Sonos Discovery

extension ControlVC: SSDPDiscoveryDelegate {
    
    func searchForDevices() {
        self.stopDiscovery()
        self.lastDiscoveryDeviceList.removeAll()
        self.devicesFoundCurrentSearch = 0
        
        print("Searching devices")
        // Create the request for Sonos ZonePlayer devices
        let zonePlayerTarget = SSDPSearchTarget.deviceType(schema: SSDPSearchTarget.upnpOrgSchema, deviceType: "ZonePlayer", version: 1)
        let request = SSDPMSearchRequest(delegate: self, searchTarget: zonePlayerTarget)
        
        // Start a discovery session for the request and timeout after 10 seconds of searching.
        self.session = try! discovery.startDiscovery(request: request, timeout: 10.0)
    }
    
    func stopDiscovery() {
        self.session?.close()
        self.session = nil
    }
    
    func discoveredDevice(response: SSDPMSearchResponse, session: SSDPDiscoverySession) {
        //        print("Found device \(response)")
        retrieveDeviceInfo(response: response)
    }
    
    func retrieveDeviceInfo(response: SSDPMSearchResponse) {
        URLSession.init(configuration: URLSessionConfiguration.default).dataTask(with: response.location) { (data, resp, err) in
            if let data = data {
                self.devicesFoundCurrentSearch += 1
                let xml =  SWXMLHash.parse(data)
                let udn = xml["root"]["device"]["UDN"].element?.text
                //Check if device is already available
                if let sonos = self.sonosSystems.first(where: {$0.udn == udn}) {
                    //Update the device
                    sonos.update(withXML: xml, url: response.location)
                    sonos.updateAll {
                        self.updateGroups(sonos: sonos)
                    }
                    self.lastDiscoveryDeviceList.append(sonos)
                }else {
                    let sonosDevice = SonosController(xml: xml, url: response.location, { (sonos) in
                        self.updateGroups(sonos: sonos)
                        
                        DispatchQueue.main.async {
                            self.addDeviceToList(sonos: sonos)
                        }
                    })
                    self.lastDiscoveryDeviceList.append(sonosDevice)
                }
            }
            }.resume()
    }
    
    func sortSpeakers() {
        //Sort the sonos systems
        self.sonosSystems.sort { (lhs, rhs) -> Bool in
            return  lhs.readableName < rhs.readableName
        }
    }
    
    func discoveredService(response: SSDPMSearchResponse, session: SSDPDiscoverySession) {
        print("Found service \(response)")
    }
    
    func closedSession(_ session: SSDPDiscoverySession) {
        print("Session closed")
        self.updateState()
        
        self.removeOldDevices()
    }
    
    enum ShowState {
        case groups
        case speakers
    }
}

extension ControlVC {
    // MARK: Storyboard instantiation
    static func freshController() -> ControlVC {
        //1.
        let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        //2.
        let identifier = NSStoryboard.SceneIdentifier(rawValue: "VolumeControlVC")
        //3.
        guard let viewcontroller = storyboard.instantiateController(withIdentifier: identifier) as? ControlVC else {
            fatalError("Why cant i find QuotesViewController? - Check Main.storyboard")
        }
        return viewcontroller
    }
}

//MARK: Sonos Delegate
extension ControlVC: SonosControllerDelegate {
    func didUpdateActiveState(forSonos sonos: SonosController, isActive: Bool) {
        self.updateState()
    }
}

extension ControlVC: SonosSpeakerGroupDelegate {
    func didChangeActiveState(group: SonosSpeakerGroup) {
        //Deactivate other groups
        for g in self.sonosGroups.values {
            guard g != group else {continue}
            g.isActive = false
            self.groupButtons[g]?.state = .off
        }
        self.updateState()
    }
}


