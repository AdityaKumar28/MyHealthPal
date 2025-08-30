//
//  FoodScannerView.swift
//  MyHealthPal
//
//  Created by Aditya Kumar on 24/08/25.
//

import SwiftUI
import UIKit

struct FoodScannerView: UIViewControllerRepresentable {
    var onImageCaptured: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        print("📸 [FoodScannerView] Initializing camera UI")
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No need to update
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: FoodScannerView

        init(_ parent: FoodScannerView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            print("📸 [FoodScannerView] Image captured")

            picker.dismiss(animated: true)

            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            } else {
                print("⚠️ [FoodScannerView] Failed to get image from picker")
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            print("❌ [FoodScannerView] User canceled image picker")
            picker.dismiss(animated: true)
        }
    }
}
