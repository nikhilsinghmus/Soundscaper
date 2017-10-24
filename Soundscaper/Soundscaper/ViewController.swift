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

class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    
    // Constants
    fileprivate let microphone = AKMicrophone()
    
    // Variables
    fileprivate var nodes: [NodeSample] = [NodeSample(nil, nil, nil)]
    fileprivate var minimum = 0
    fileprivate var index = 0
    fileprivate var nodeRecorder: AKNodeRecorder?
    fileprivate var file: AKAudioFile?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // SceneKit
        sceneView.delegate = self
        sceneView.showsStatistics = false
        let scene = SCNScene()
        sceneView.scene = scene
        
        // Gesture Recognizers
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(removeNode(_:)))
        view.addGestureRecognizer(swipe)
        
        // AudioKit
        if let inputs = AudioKit.inputDevices {
            do {
                try AudioKit.setInputDevice(inputs[0])
                try microphone.setDevice(inputs[0])
            } catch {
                print(error)
            }
        }
        
        let silence = AKBooster(microphone, gain: 0)
        AudioKit.output = silence
        AudioKit.start()
        microphone.start()
        
        // DisplayLink
        let displayLink = CADisplayLink(target: self, selector: #selector(checkAmps))
        displayLink.add(to: .main, forMode: .defaultRunLoopMode)
    }
    
    @objc func removeNode(_ gesture: UIGestureRecognizer) {
        let result = sceneView.hitTest(gesture.location(in: sceneView), options: [:])
        
        if result.count > 0 {
            nodes = nodes.filter { $0.node != result[0].node }
            result[0].node.removeFromParentNode()
        } else {
            if let NodeSample = nodes.popLast() {
                NodeSample.node?.removeFromParentNode()
            }
        }
    }
    
    @objc func checkAmps() {
        for i in 0 ..< nodes.count {
            if let node = nodes[i].node, let camera = sceneView.session.currentFrame?.camera {
                nodes[i].amp = abs(1 - (abs(node.position.z - (camera.transform.columns.3.z)) - 0.5) * 2)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
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

extension ViewController {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        do {
            file = try AKAudioFile()
            microphone.outputNode.removeTap(onBus: 0)
            nodeRecorder = try AKNodeRecorder(node: microphone, file: file)
            try nodeRecorder?.record()
        } catch {
            print(error)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        nodeRecorder?.stop()
        
        guard let file = file else { return }
        
        let player: AKAudioPlayer?
        do {
            player = try AKAudioPlayer(file: file)
            player?.looping = true
            AudioKit.output = player
            player?.play()
        } catch {
            print(error)
            return
        }
        
        guard let currentFrame = sceneView.session.currentFrame else {
            return
        }
        
        let sphereNode = SCNNode(geometry: SCNSphere(radius: 0.01))
        let psys = SCNParticleSystem(named: "P1", inDirectory: nil)!
        psys.emitterShape = SCNSphere(radius: 0.01)
        sphereNode.addParticleSystem(psys)
        sceneView.scene.rootNode.addChildNode(sphereNode)
        
        var translation = matrix_identity_float4x4
        translation.columns.3.z = -0.1
        print(currentFrame.camera.transform)
        sphereNode.simdTransform = matrix_multiply(currentFrame.camera.transform, translation)
        sphereNode.localRotate(by: SCNQuaternion.init(1, 0, 0, 0))
        
        nodes.append(NodeSample(sphereNode, psys, player))
        
        let _: () = {
            minimum = 1
        }()
    }
}

