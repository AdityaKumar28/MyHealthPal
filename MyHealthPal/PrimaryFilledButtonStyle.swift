//
//  PrimaryFilledButtonStyle.swift
//  MyHealthPal
//
//  Created by Aditya Kumar on 30/08/25.
//

import SwiftUI

/// A filled button whose label text stays readable when enabled/disabled.
struct PrimaryFilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white) // keep text white
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(configuration.isPressed ? Color.accentColor.opacity(0.8)
                                                : Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.95 : 1.0)
    }
}
