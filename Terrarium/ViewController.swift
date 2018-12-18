//
//  ViewController.swift
//  Terrarium
//
//  Created by Alexandra Berke on 12/11/18.
//  Copyright © 2018 aberke. All rights reserved.
//

import ARKit
import SceneKit
import UIKit


// ARKit measurement unit is meters.
// Terrarium window is 12x12 inches
var terrariumWindowSize = CGFloat(0.3)
// Set debug to true to highlight found AR target
var debug = false


class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var label: UILabel!
    var anchorFound: Bool = false
    
    override func viewDidLoad() {
        configureLighting()
        super.viewDidLoad()
        sceneView.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        resetTrackingConfiguration()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    func configureLighting() {
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true
    }
    
    @IBAction func resetButtonDidTouch(_ sender: UIBarButtonItem) {
        resetTrackingConfiguration()
    }
    
    func resetTrackingConfiguration() {
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) else { return }
        let configuration = ARWorldTrackingConfiguration()
        configuration.environmentTexturing = .automatic
        configuration.detectionImages = referenceImages
        let options: ARSession.RunOptions = [.resetTracking, .removeExistingAnchors]
        sceneView.session.run(configuration, options: options)
        self.anchorFound = false
        // Show the searching label and hide the refresh toolbar until the achor is found.
        self.label.text = "searching..."
        self.label.isHidden = false
    }
    
    /*
     The terrarium window is found by tracking an AR target/anchor on the bottom left corner of its frame.  Once the terrarium is found, the renderer takes a precaptured image and maps it onto a plane to cover the terrarium window.
     It maps the mirror of that image on to planes to the left and right of the terrarium window.
    */
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if (self.anchorFound) {
            return
        }
        guard let imageAnchor = anchor as? ARImageAnchor else { return }
        let referenceImage = imageAnchor.referenceImage
        self.anchorFound = true
        
        // Hide the searching label and show the refresh toolbar
        DispatchQueue.main.async {
            self.label.isHidden = true
        }
        
        if debug {
            let debugPlaneNode = getDebugPlaneNode(withReferenceImage: referenceImage)
            node.addChildNode(debugPlaneNode)
        }
        
        let terrariumWindowPlaneNode = getTerrariumWindowPlaneNode(withReferenceImage: referenceImage)
        let leftPlaneNode = getLeftPlaneNode(withReferenceImage: referenceImage)
        let rightPlaneNode = getRightPlaneNode(withReferenceImage: referenceImage)
        node.addChildNode(terrariumWindowPlaneNode)
        node.addChildNode(leftPlaneNode)
        node.addChildNode(rightPlaneNode)
        
        // Prepare the materials to be applied to the plane nodes.
        // The materials have physically based reflective properties
        // to reflect light on top of their images.
        // Make the terrarium window image on the plane more like the environment:
        // If a dark AR target is detected, use the darker terrarium image
        // Otherwise use the lighter terrarium image.
        let image: UIImage;
        if (referenceImage.name == "city-science-logo-dark") {
            image = UIImage(named: "terrarium-window-dark")!;
        } else {
            image = UIImage(named: "terrarium-window-light-unnatural-warm")!;
        }
        let imageMaterial = SCNMaterial()
        imageMaterial.diffuse.contents = image
        imageMaterial.lightingModel = .physicallyBased
        imageMaterial.metalness.contents = 0.5
        imageMaterial.roughness.contents = 0
        // The mirror image material is identical to the image material, but it is transformed with a mirror
        let mirrorImageMaterial = SCNMaterial()
        mirrorImageMaterial.diffuse.contents = image
        mirrorImageMaterial.lightingModel = .physicallyBased
        mirrorImageMaterial.metalness.contents = 0.5
        mirrorImageMaterial.roughness.contents = 0
        mirrorImageMaterial.diffuse.contentsTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(-1, 1, 1), 1, 0, 0)
        // Apply the mirrors to the plane nodes
        terrariumWindowPlaneNode.geometry?.firstMaterial = imageMaterial
        rightPlaneNode.geometry?.firstMaterial = mirrorImageMaterial
        leftPlaneNode.geometry?.firstMaterial = mirrorImageMaterial
    }
    
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return true
    }

    func getDebugPlaneNode(withReferenceImage image: ARReferenceImage) -> SCNNode {
        // Creates and returns a plane to visualize the position of the detected image.
        let plane = SCNPlane(width: image.physicalSize.width,
                             height: image.physicalSize.height)
        let node = SCNNode(geometry: plane)
        node.opacity = 0.25
        node.eulerAngles.x = -.pi / 2
        return node
    }
    
    func getTerrariumWindowPlaneNode(withReferenceImage image: ARReferenceImage) -> SCNNode {
        // Returns a node for a plane that is in the position of the terrarium window relative to the AR reference image.
        let plane = SCNPlane(width: terrariumWindowSize, height: terrariumWindowSize)
        let node = SCNNode(geometry: plane)
        //`SCNPlane` is vertically oriented in its local coordinate space, but
        //`ARImageAnchor` assumes the image is horizontal in its local space, so
        //rotate the plane to match.
        node.eulerAngles.x = -.pi / 2
        let translateX = ((0.5)*Float(image.physicalSize.width) + (0.5)*Float(terrariumWindowSize))
        let translateY = (-0.5)*(Float(image.physicalSize.height)+Float(terrariumWindowSize))
        node.position = SCNVector3(translateX, 0.0, translateY)
        return node
    }
    
    func getLeftPlaneNode(withReferenceImage image: ARReferenceImage) -> SCNNode {
        // Returns a plane that is identical to the main terrarium window,
        // but that is translated to the left of it.
        let node = getTerrariumWindowPlaneNode(withReferenceImage: image)
        node.position.x = node.position.x - Float(terrariumWindowSize)
        return node
    }
    
    func getRightPlaneNode(withReferenceImage image: ARReferenceImage) -> SCNNode {
        // Returns a plane that is identical to the main terrarium window,
        // but that is translated to the right of it.
        let node = getTerrariumWindowPlaneNode(withReferenceImage: image)
        node.position.x = node.position.x + Float(terrariumWindowSize)
        return node
    }
}
