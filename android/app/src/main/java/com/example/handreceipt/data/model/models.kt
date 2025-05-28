package com.example.handreceipt.data.model

import com.google.gson.annotations.SerializedName
import java.util.Date
import java.util.UUID

// Authentication Models
data class LoginCredentials(
    val username: String,
    val password: String // Sent plain text over HTTPS
)

data class LoginResponse(
    @SerializedName("userId") // Keep potential backend key name
    val userId: UUID, 
    val username: String, // Often returned for convenience
    val role: String?, // User role is important
    val message: String? // Optional success message
    // Full user object might be returned instead/as well
    // val user: User? 
)

// Primary User model
data class User(
    val id: UUID,
    val username: String,
    val rank: String?,
    val firstName: String?,
    val lastName: String?,
    val role: String? // e.g., "Commander", "Soldier", "ADMIN"
)

// Simplified User model for embedding (e.g., in Transfer)
data class UserSummary(
    val id: UUID,
    val username: String,
    val rank: String?,
    val lastName: String?
    // Add firstName if needed for display
)

// Reference Database Model
data class ReferenceItem(
    val id: UUID, 
    val nsn: String, // National Stock Number
    val itemName: String,
    val description: String?,
    val manufacturer: String?,
    val imageUrl: String?,
    val lin: String?, // Added from initial models.kt version
    val partNumber: String?, // Added from initial models.kt version
    val unitOfIssue: String?, // Added from initial models.kt version
    val price: Double?, // Added from initial models.kt version
    val category: String? // Added from initial models.kt version
)

// Property/Inventory Model
data class Property(
    val id: UUID,
    @SerializedName("serialNumber") // Explicit mapping example
    val serialNumber: String,
    val nsn: String, // Link to ReferenceItem
    val status: String, // Consider an Enum if statuses are fixed
    val location: String?,
    val assignedToUserId: UUID?, // Changed to UUID?
    
    // Optional fields from more detailed Property.kt definition
    val itemName: String, // Often included directly for convenience
    val description: String?,
    val manufacturer: String?,
    val imageUrl: String?,
    val lastInventoryDate: Date?,
    val acquisitionDate: Date?,
    val notes: String?,
    
    // Optionally populated by backend join or separate query
    val referenceItem: ReferenceItem? = null, 
    val assignedToUser: UserSummary? = null // Added optional assigned user summary
)

// --- Transfer Models --- 

enum class TransferStatus {
    PENDING, APPROVED, REJECTED, CANCELLED, UNKNOWN // Added UNKNOWN for safety
}

data class Transfer(
    val id: UUID,
    val propertyId: UUID,
    @SerializedName("propertySerialNumber") // Keep explicit names
    val propertySerialNumber: String, 
    @SerializedName("propertyName")
    val propertyName: String?, 
    val fromUserId: UUID,
    val toUserId: UUID,
    val status: TransferStatus,
    val requestTimestamp: Date,
    val approvalTimestamp: Date?,
    val fromUser: UserSummary? = null, // Optionally populated
    val toUser: UserSummary? = null // Optionally populated
)

// Model for initiating a transfer request
data class TransferRequest(
    val propertyId: UUID, 
    val targetUserId: UUID
)

// Model for approving/rejecting a transfer (if backend requires a body)
// data class TransferActionRequest(
//    val decision: String // e.g., "APPROVE" or "REJECT"
// ) 