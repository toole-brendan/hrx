package com.example.handreceipt.ui.screens

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// Represents the structure of a Property item fetched from the backend.
// Uses kotlinx.serialization for JSON parsing.
@Serializable
data class Property(
    // Assuming Go's uint maps to Kotlin's Long for JSON numbers that might exceed Int.MaxValue
    // Alternatively, use Int if you are certain IDs won't exceed 2^31 - 1
    @SerialName("id") val id: Long,

    // Map JSON key explicitly using @SerialName to match Go backend's JSON output.
    // Adjust the string value if the Go JSON tag is different (e.g., "property_model_id").
    @SerialName("propertyModelId") val propertyModelId: Long? = null, // Nullable to match Go *uint

    @SerialName("name") val name: String,
    @SerialName("serialNumber") val serialNumber: String,
    @SerialName("description") val description: String? = null, // Nullable
    @SerialName("currentStatus") val currentStatus: String,
    @SerialName("assignedToUserId") val assignedToUserId: Long? = null, // Nullable

    // Dates are expected as ISO8601 strings
    @SerialName("lastVerifiedAt") val lastVerifiedAt: String? = null,
    @SerialName("lastMaintenanceAt") val lastMaintenanceAt: String? = null,
    @SerialName("createdAt") val createdAt: String,
    @SerialName("updatedAt") val updatedAt: String
)

// Note: The existing ReferenceItem data class in ReferenceDatabaseBrowserScreen.kt
// might need updates or replacement depending on how you structure your domain models.
// You might create a separate ReferenceItem.kt or merge relevant fields if needed. 