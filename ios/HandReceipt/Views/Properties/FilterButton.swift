//
//  FilterButton.swift
//  HandReceipt
//
//  Filter button component for properties view
//

import SwiftUI

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFonts.caption)
                .foregroundColor(isSelected ? .white : AppColors.secondaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? AppColors.primaryText : AppColors.secondaryBackground)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? AppColors.primaryText : AppColors.border, lineWidth: 1)
                )
                .compatibleKerning(AppFonts.wideKerning)
        }
        .buttonStyle(PlainButtonStyle())
    }
} 