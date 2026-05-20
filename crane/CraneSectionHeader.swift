//
//  CraneSectionHeader.swift
//  crane
//

import SwiftUI

struct CraneSectionHeader: View {
    let title: String
    var trailing: String?
    var trailingActionTitle: String?
    var trailingAction: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .craneText(.section)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(CraneFont.ui(10, weight: .medium))
                    .foregroundStyle(.craneInkTertiary)
            } else if let trailingActionTitle, let trailingAction {
                Button(trailingActionTitle, action: trailingAction)
                    .buttonStyle(.craneSecondary)
            }
        }
    }
}
