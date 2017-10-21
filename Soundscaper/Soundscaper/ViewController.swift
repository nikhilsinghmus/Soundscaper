//
//  ViewController.swift
//  Soundscaper
//
//  Copyright © 2017 Nikhil Singh. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import AudioKit

struct NodePitch {
    var node: SCNNode?
    var pitch: Int?
    var amp: Double = 0
    
    init(_ scnnode: SCNNode?, _ midiPitch: Int) {
        node = scnnode
        pitch = midiPitch
    }
}

class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    
    var nodes: [NodePitch] = [NodePitch(nil, 0)]
    var minimum = 0
    var index = 0
    
    let microphone = AKMicrophone()
    var freqTracker: AKFrequencyTracker?
    let string = AKPluckedString()
    
    lazy var callback = AKPeriodicFunction(frequency: 2, handler: {
        
        self.index = ((self.index + 1) >= self.nodes.count) ? self.minimum : self.index + 1
        
        self.checkAmps()
        let amp = self.nodes[self.index].amp
        let pitch = self.nodes[self.index].pitch

        if let pitch = pitch, pitch > 0 {
            self.string.trigger(frequency: pitch.midiNoteToFrequency(), amplitude: Double(amp * 20))
        }
        
        DispatchQueue.main.async {
            if let node = self.nodes[self.index].node {
                UIView.animate(withDuration: 0.5, animations: {
                    (node.geometry as! SCNSphere).radius = 0.1
                })
            }
        }
        
        let deadlineTime = DispatchTime.now() + (60 / 120) / 10.0
        DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
            if let node = self.nodes[self.index].node {
                UIView.animate(withDuration: 0.5, animations: {
                    (node.geometry as! SCNSphere).radius = 0.05
                })
            }
        }
    })
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.showsStatistics = false
        let scene = SCNScene()
        sceneView.scene = scene
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tap)
        
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(removeNode(_:)))
        view.addGestureRecognizer(swipe)
        
        // AudioKit Stuff
        if let inputs = AudioKit.inputDevices {
            do {
                try AudioKit.setInputDevice(inputs[0])
                try microphone.setDevice(inputs[0])
            } catch {
                print(error)
            }
        }
        
        let mic = AKBooster(microphone)
        freqTracker = AKFrequencyTracker(mic, hopSize: 200, peakCount: 2_000)
        microphone.start()
        freqTracker?.start()
        
        let silence = AKBooster(freqTracker, gain: 0)
        AudioKit.output = silence
        AudioKit.output = string
        
        AudioKit.start(withPeriodicFunctions: callback)
        callback.start()
    }
    
    @objc func removeNode(_ gesture: UIGestureRecognizer) {
        if nodes.count > 2 {
            if let lastNode = nodes.popLast() {
                lastNode.node?.removeFromParentNode()
            }
        }
    }
    
    func checkAmps() {
        for i in 0 ..< nodes.count {
            if let node = nodes[i].node, let camera = sceneView.session.currentFrame?.camera {
                nodes[i].amp = abs(1 - (abs(node.position.z - (camera.transform.columns.3.z)) - 0.5) * 2)
            }
        }
    }
    
    func hz2midi(_ frequency: Double) -> Int {
        guard frequency > 0 else { return 0 }
        return Int(round(69 + (12 * log2(frequency/440.0))))
    }

    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        guard let currentFrame = sceneView.session.currentFrame else {
            return
        }
        
        let sphereNode = SCNNode(geometry: SCNSphere(radius: 0.05))
        sceneView.scene.rootNode.addChildNode(sphereNode)
        
        var translation = matrix_identity_float4x4
        translation.columns.3.z = -0.1
        sphereNode.simdTransform = matrix_multiply(currentFrame.camera.transform, translation)
        
        nodes.append(NodePitch(sphereNode, hz2midi(freqTracker?.frequency ?? 440)))
        
        let _: () = {
            minimum = 1
        }()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    // MARK: - ARSCNViewDelegate
    
    /*
     // Override to create and configure nodes for anchors added to the view's session.
     func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
     let node = SCNNode()
     
     return node
     }
     */
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}
