//
//  ContentView.swift
//  RKCubeRotation
//

import SwiftUI
import RealityKit
import Combine

class CubeState {
    var rotationX: Float = .zero
    var rotationY: Float = .zero
    var velocityX: Float = .zero
    var velocityY: Float = .zero
}

class CubeSpaceView: ARView {
    var arView: ARView {return self}
    private var cubeUpdate: Cancellable?
    var cubeState = CubeState()
    
    @MainActor required dynamic override init(frame frameRect: CGRect, cameraMode: ARView.CameraMode, automaticallyConfigureSession: Bool) {
        cubeState.rotationX = 0
        cubeState.rotationY = 0
        super.init(frame: frameRect, cameraMode: cameraMode, automaticallyConfigureSession: automaticallyConfigureSession)
    }
    
    @MainActor required dynamic init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @MainActor required dynamic init(frame frameRect: CGRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    @objc func handlePan(sender:UIPanGestureRecognizer){
        let v = sender.velocity(in: arView)
        self.cubeState.velocityX = Float(v.x)
        self.cubeState.rotationX = self.cubeState.rotationX + Float(v.x) * 0.0001
    }
    
    func getSingleCube(x:Float, y:Float, z:Float, mesh:MeshResource, materials:[SimpleMaterial]) -> ModelEntity {
        let model = ModelEntity(mesh: mesh, materials: materials)
        model.position.x = x
        model.position.y = y
        model.position.z = z
        model.name = "Cube"
        model.generateCollisionShapes(recursive: true)
        return model
    }

    func getSinglePlane(width: Float, depth: Float, color: UIColor, x:Float, y:Float, z:Float, rotationAngle:Float, rotationAxis:SIMD3<Float>) -> ModelEntity {
        let planeMesh = MeshResource.generatePlane(width: width, depth: depth)
        let planeMaterial = SimpleMaterial(color: color, roughness: 0.0, isMetallic: false)
        let planeEntity = ModelEntity(mesh: planeMesh, materials: [planeMaterial])
        let planeRotation = simd_quatf(angle: rotationAngle, axis: rotationAxis)
        let planeTransform = Transform(scale:.one, rotation: planeRotation, translation: SIMD3<Float>(x,y,z))
        planeEntity.transform = planeTransform
        return planeEntity
    }
    
    func getRotationMatrix(angle:Float, axis:String) -> float4x4 {
        var rows : [SIMD4<Float>] = []
        if axis == "x" {
            rows = [
                simd_float4(1,0,0, 0),
                simd_float4(0, cos(angle),-sin(angle), 0),
                simd_float4(0,sin(angle),cos(angle), 0),
                simd_float4(0,0,0, 1)
            ]
        }
        else if axis == "y" {
            rows = [
                simd_float4(cos(angle),0,sin(angle), 0),
                simd_float4(0,1,0, 0),
                simd_float4(-sin(angle),0,cos(angle), 0),
                simd_float4(0,0,0, 1)
            ]
        }
        return float4x4(rows: rows)
    }
    
    func setup(){

        let faceAnchor = Entity()

        let frontFace = getSinglePlane(width: 5, depth: 5, color: .yellow, x: 0, y: 0, z: 2.5, rotationAngle: Float(Double.pi / 2),rotationAxis: SIMD3<Float>(1,0,0))
        let bottomFace = getSinglePlane(width: 5, depth: 5, color: .red, x: 0, y: -2.5, z: 0, rotationAngle: Float(Double.pi),rotationAxis: SIMD3<Float>(1,0,0))
        let topFace = getSinglePlane(width: 5, depth: 5, color: .green, x: 0, y: 2.5, z: 0, rotationAngle: 0,rotationAxis: SIMD3<Float>(0,1,0))
        let leftFace = getSinglePlane(width: 5, depth: 5, color: .blue, x: -2.5, y: 0, z: 0, rotationAngle: Float(Double.pi / 2),rotationAxis: SIMD3<Float>(0,0,1))
        let rightFace = getSinglePlane(width: 5, depth: 5, color: .purple, x: 2.5, y: 0, z: 0, rotationAngle: -Float(Double.pi / 2),rotationAxis: SIMD3<Float>(0,0,1))
        let backFace = getSinglePlane(width: 5, depth: 5, color: .white, x: 0, y: 0, z: -2.5, rotationAngle: -Float(Double.pi / 2),rotationAxis: SIMD3<Float>(1,0,0))
        
        let axesAnchors = AnchorEntity(world: [0,0,0])

        faceAnchor.addChild(frontFace)
        faceAnchor.addChild(bottomFace)
        faceAnchor.addChild(topFace)
        faceAnchor.addChild(leftFace)
        faceAnchor.addChild(rightFace)
        faceAnchor.addChild(backFace)
        
        axesAnchors.addChild(faceAnchor)
        
        arView.scene.addAnchor(axesAnchors)
        arView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(sender:))))

        let camera = PerspectiveCamera()
        let cameraAnchor = AnchorEntity(world:[0,0,0])
        camera.look(at: SIMD3<Float>(x: 0, y: 0, z: 0), from: SIMD3<Float>(x: 0, y: 0, z: 20), relativeTo: nil)
        cameraAnchor.addChild(camera)
        arView.scene.addAnchor(cameraAnchor)

        var rotationX_Matrix : float4x4 = float4x4()
        self.cubeUpdate = scene.subscribe(to: SceneEvents.Update.self) { event in
            print("v.x:\(self.cubeState.velocityX) v.y\(self.cubeState.velocityY)")
            
            self.cubeState.rotationX = self.cubeState.rotationX + self.cubeState.velocityX * 0.0001
            rotationX_Matrix = self.getRotationMatrix(angle: self.cubeState.rotationX, axis: "y")

            let anchorTransform = Transform(matrix: rotationX_Matrix)
            faceAnchor.transform = anchorTransform
            
            if abs(self.cubeState.velocityX) > 100 {
                if self.cubeState.velocityX > 100 {
                    self.cubeState.velocityX = round(self.cubeState.velocityX) - 100
                }
                else {
                    self.cubeState.velocityX = round(self.cubeState.velocityX) + 100
                }
            }
            else if abs(self.cubeState.velocityX) > 10 {
                if self.cubeState.velocityX > 0 {
                    self.cubeState.velocityX = round(self.cubeState.velocityX) - 10
                }
                else {
                    self.cubeState.velocityX = round(self.cubeState.velocityX) + 10
                }
            }
            else if abs(self.cubeState.velocityX) > 0 {
                if self.cubeState.velocityX > 0 {
                    self.cubeState.velocityX = round(self.cubeState.velocityX) - 1
                }
                else {
                    self.cubeState.velocityX = round(self.cubeState.velocityX) + 1
                }
            }
        }
    }
}

struct ContentView : View {
    @State private var cubeState = CubeState()
    var body: some View {
        VStack {
            ARViewContainer(cubeState).edgesIgnoringSafeArea(.all)
        }
    }
}


struct ARViewContainer: UIViewRepresentable {
    private var cubeState: CubeState

    public init(_ cubeState: CubeState){
        self.cubeState = cubeState
    }

    func makeUIView(context: Context) -> ARView {
        let arView = CubeSpaceView(frame: .zero, cameraMode: ARView.CameraMode.nonAR, automaticallyConfigureSession: false)
        arView.setup()
        arView.cubeState = cubeState
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
    }
}

#Preview {
    ContentView()
}
