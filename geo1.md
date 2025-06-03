Thanks for the details. I’ll now review your SwiftUI/UIKit-based iOS app alongside your Go/Gin backend and examine the `handreceipt/sql` directory for your database schema. Based on that, I’ll provide an overview of your app’s current capabilities, suggest what should be included in the 'Change Password' and 'Edit Profile' screens, provide SwiftUI screen code, and indicate if SQL migrations are needed to support those features. I’ll update you shortly.


# Implementing User Profile Editing and Password Change

## Overview of Current User Capabilities

The **HandReceipt** app already supports basic user account functionality. Users are stored in a `users` table with fields for unique username and email, a bcrypt-hashed password, first and last name, and military-specific info like rank and unit. Each user also has a role (`user`, `admin`, `super_admin`, etc.) and an account status (active, inactive, etc.) to control permissions. The backend tracks user sessions and refresh tokens for authentication, and audit logs record user actions (e.g. logins) for compliance. Currently, users can log in and the app likely displays their profile details (e.g. name, rank/unit) and any equipment or hand receipts associated with them. However, there is no existing UI to let a user update their profile information or change their password – those features need to be added.

Notably, the database is already designed to support these features. The `users` schema includes profile fields (first name, last name, rank, unit, email) that can be updated, and a `password_hash` field for storing secure passwords. Triggers ensure that whenever a user record is updated, the `updated_at` timestamp is refreshed. A default admin user is pre-created (with a known bcrypt hash for password) to bootstrap the system. Given this foundation, we can implement **Edit Profile** and **Change Password** functionality by building on the existing architecture.

## Design for "Edit Profile" and "Change Password" Features

**Edit Profile Page:** The Edit Profile screen should present a form allowing users to view and modify their personal information. Key fields to include are: **First Name**, **Last Name**, **Email**, **Rank**, and **Unit** (since these are stored in the schema). The form loads with the user’s current info and lets them make changes. Validation is important: first/last name should not be empty (required), and email should be in a valid format. Rank and unit can be optional or free-form text (as the database doesn’t enforce specific values for them). The UI should prevent invalid submissions – for example, disable the Save button until required fields are filled and the email looks valid. When the user taps “Save,” the app will send the updated profile data to the backend via an authenticated request. On success, the app can show a confirmation (e.g. a brief alert or toast that profile changes were saved) and update the local displayed profile info. If the backend returns an error (e.g. email already in use or other validation issue), the UI should display an error message so the user can adjust and retry.

**Change Password Page:** The Change Password screen should be separate from general profile editing for security. It will have three fields: **Current Password**, **New Password**, and **Confirm New Password**. This separation ensures the user intentionally re-authenticates within the session to change their credential. Validation here includes ensuring the new password meets complexity requirements (for example, minimum length of 8 characters and not too common or weak) and that the confirmation matches the new password. The user must also correctly enter their current password. The form should clearly indicate errors (e.g. “Passwords do not match” or “Current password is incorrect”) before or after submission. On submission, the app will call a protected API endpoint to update the password. The backend will verify the current password by comparing it with the stored hash, and if it matches, will accept the new password (storing its bcrypt hash). After a successful password change, the app can inform the user (e.g. “Password updated successfully”). For security, consider forcing a logout of all other sessions or tokens for that user. The user might remain logged in on the current device (if the app uses JWTs or tokens, those may still be valid), but it’s good practice to prompt re-login or at least invalidate other sessions after a password change. The implementation should also log this event (e.g. in the audit log) as a password update for security tracking.

## SwiftUI Frontend Implementation

### Edit Profile Screen (SwiftUI)

On iOS, we can create an **Edit Profile** view using SwiftUI forms. This view will fetch the current user’s profile (perhaps stored in app state after login) and allow editing. Form fields are bound to `@State` properties so changes update the UI. A **Save** button triggers validation and sends the update request. For example:

```swift
struct EditProfileView: View {
    // Assuming a ViewModel or environment object provides the current user info
    @State private var firstName: String
    @State private var lastName: String
    @State private var email: String
    @State private var rank: String
    @State private var unit: String
    
    @State private var showSaveConfirmation = false
    @State private var errorMessage: String? = nil
    
    init(user: User) {
        // Initialize state with existing user info
        _firstName = State(initialValue: user.firstName)
        _lastName  = State(initialValue: user.lastName)
        _email     = State(initialValue: user.email)
        _rank      = State(initialValue: user.rank ?? "")
        _unit      = State(initialValue: user.unit ?? "")
    }
    
    var formIsValid: Bool {
        // Example validation: first/last name not empty, email contains "@" 
        !firstName.isEmpty && !lastName.isEmpty &&
        !email.isEmpty && email.contains("@")
    }
    
    var body: some View {
        Form {
            Section(header: Text("Personal Info")) {
                TextField("First Name", text: $firstName)
                TextField("Last Name", text: $lastName)
            }
            Section(header: Text("Unit Details")) {
                TextField("Rank", text: $rank)
                TextField("Unit/Organization", text: $unit)
            }
            Section(header: Text("Contact")) {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }
            
            if let error = errorMessage {
                // Show error message if any
                Text(error).foregroundColor(.red)
            }
            
            Button(action: saveProfile) {
                Text("Save Changes")
            }
            .disabled(!formIsValid)
        }
        .navigationTitle("Edit Profile")
        .alert(isPresented: $showSaveConfirmation) {
            Alert(title: Text("Profile Updated"),
                  message: Text("Your profile details have been saved."),
                  dismissButton: .default(Text("OK")))
        }
    }
    
    func saveProfile() {
        guard formIsValid else { return }
        errorMessage = nil
        // Prepare JSON payload
        let updatedInfo: [String: Any] = [
            "first_name": firstName,
            "last_name": lastName,
            "email": email,
            "rank": rank,
            "unit": unit
        ]
        // Assume we have an API client to send the request (not shown for brevity)
        API.updateUserProfile(with: updatedInfo) { result in
            switch result {
            case .success:
                showSaveConfirmation = true
            case .failure(let error):
                // Display error (e.g. email already taken, network issue, etc.)
                errorMessage = error.localizedDescription
            }
        }
    }
}
```

In this SwiftUI view, the form is grouped into sections for clarity. The **Personal Info** section contains name fields, **Unit Details** for rank and unit, and **Contact** for email. The `formIsValid` computed property ensures basic validation (in practice you might do more robust checks or use Combine to debounce validation). The Save button is disabled until the form is valid. Tapping **Save Changes** calls `saveProfile()`, which sends the data to the backend (using a hypothetical `API.updateUserProfile` method – this would use `URLSession` or a networking layer to call the appropriate endpoint). Based on the callback, we either show a success alert or an error message. The UI provides immediate feedback by highlighting errors and confirming success, making it user-friendly.

### Change Password Screen (SwiftUI)

The **Change Password** view is also a SwiftUI form but focused on credential input. We use secure input fields and ensure the new password is confirmed correctly:

```swift
struct ChangePasswordView: View {
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmNewPassword: String = ""
    
    @State private var errorMessage: String? = nil
    @State private var showSuccessAlert = false
    
    var passwordsMatch: Bool {
        newPassword == confirmNewPassword && !newPassword.isEmpty
    }
    var newPasswordStrong: Bool {
        newPassword.count >= 8  // basic length check; more complexity checks can be added
    }
    
    var formIsValid: Bool {
        !currentPassword.isEmpty && passwordsMatch && newPasswordStrong
    }
    
    var body: some View {
        Form {
            Section(header: Text("Current Password")) {
                SecureField("Enter current password", text: $currentPassword)
            }
            Section(header: Text("New Password")) {
                SecureField("Enter new password", text: $newPassword)
                SecureField("Confirm new password", text: $confirmNewPassword)
            }
            
            if let error = errorMessage {
                Text(error).foregroundColor(.red)
            }
            
            Button(action: changePassword) {
                Text("Update Password")
            }
            .disabled(!formIsValid)
        }
        .navigationTitle("Change Password")
        .alert(isPresented: $showSuccessAlert) {
            Alert(title: Text("Password Changed"),
                  message: Text("Your password has been updated."),
                  dismissButton: .default(Text("OK")))
        }
    }
    
    func changePassword() {
        guard formIsValid else { return }
        errorMessage = nil
        let payload = [
            "current_password": currentPassword,
            "new_password": newPassword
        ]
        API.changePassword(with: payload) { result in
            switch result {
            case .success:
                showSuccessAlert = true
                currentPassword = ""; newPassword = ""; confirmNewPassword = ""
            case .failure(let error):
                // If current password was wrong or other issues
                errorMessage = error.localizedDescription
            }
        }
    }
}
```

In this view, the **Current Password** section has a SecureField (so input is not visible). The **New Password** section has two SecureFields for the new password and its confirmation. We enforce that the new password is at least 8 characters (per common policy) and that the two entries match. The **Update Password** button is enabled only when the form is valid (non-empty current password, and new password meets criteria and matches confirmation). On tap, `changePassword()` is called, constructing a request with `current_password` and `new_password`. The `API.changePassword` call (to be implemented in the networking layer) will contact the backend. If the backend responds with success, we show an alert confirming the change and clear the fields. If there's an error (e.g. the current password was incorrect as per the server’s check, or the new password didn’t meet some server-side rule), we set `errorMessage` to inform the user. This provides a straightforward UX for updating a password with immediate feedback on any issues.

## Backend Implementation (Go/Gin)

On the backend, we will add two new endpoints to the Gin router: one for updating profile info, and one for changing the password. Both should be **authenticated routes** (ensuring the user is logged in), and likely should require the correct user or appropriate role. In practice, we might use middleware to attach the user’s ID from their session or JWT. The routes could be defined under an API group such as `/api/users`.

**Profile Update Endpoint:** We can use an HTTP PATCH (or PUT) route like `/api/users/:id` to handle profile edits. The handler will parse the JSON body for allowed fields (first name, last name, email, rank, unit), find the user in the database, and apply the changes. For safety, the server-side should ignore or reject any fields that the user isn’t permitted to change (for example, role or status should not be client-editable by a normal user). Below is a simplified example using GORM as the ORM and assuming we have user authentication middleware:

```go
// Route registration (in setup code):
// router.PATCH("/api/users/:id", authMiddleware(), updateUserProfile)

type UpdateProfileRequest struct {
    FirstName string `json:"first_name" binding:"required"`
    LastName  string `json:"last_name"  binding:"required"`
    Email     string `json:"email"      binding:"required,email"`
    Rank      string `json:"rank"`
    Unit      string `json:"unit"`
}

func updateUserProfile(c *gin.Context) {
    // Get the user ID from the URL and the authenticated user from context
    userIDParam := c.Param("id")
    // (In a real app, you'd verify that userIDParam matches c.MustGet("userID") unless an admin)
    var req UpdateProfileRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request data"})
        return
    }
    // Look up the user in the database
    var user User
    if err := db.First(&user, "id = ?", userIDParam).Error; err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
        return
    }
    // Update allowed fields
    user.FirstName = req.FirstName
    user.LastName  = req.LastName
    user.Email     = req.Email
    user.Rank      = req.Rank
    user.Unit      = req.Unit
    // Save changes
    if err := db.Save(&user).Error; err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not update profile"})
        return
    }
    // On success, return updated user (or a subset of fields) 
    c.JSON(http.StatusOK, gin.H{
        "message": "Profile updated successfully",
        "user":    user,  // in practice, might omit sensitive fields
    })
}
```

In this handler, we use `ShouldBindJSON` with a struct that defines the expected fields and basic validations (making first name, last name, and email required, and using an email format validator). We fetch the target user by ID and then assign the new values. By using GORM’s `Save`, the updated fields are written to the database; the `updated_at` timestamp will automatically update via the trigger. The response returns a success message and possibly the updated user data so the app can refresh its display. We should ensure the email/username uniqueness – since the database has a unique constraint on email, saving a duplicate email would error. The code should catch that (the error from `Save`) and return a user-friendly message (not done in detail above due to brevity).

Also note: permission logic is important – a normal user should only update their own profile. The `authMiddleware()` (or similar) would typically attach the current user’s ID. We would compare that to `userIDParam` and if they differ (and the current user is not an admin role), we’d reject with 403 Forbidden. This ensures users cannot edit others’ profiles. Admins, however, might use the same endpoint to edit any user’s profile (if such admin functionality exists).

**Change Password Endpoint:** For password changes, define a route like `POST /api/users/:id/password` (or PATCH on a `/password` sub-resource). The handler will require the current password for verification. It should perform the following steps:

1. Authenticate the request and ensure the `:id` matches the current user (or the requester is allowed to change it, e.g. an admin resetting a user password).
2. Parse the JSON body for `current_password` and `new_password`.
3. Retrieve the user from the database (to get the stored `password_hash`).
4. Use bcrypt to compare the provided current password with the stored hash.
5. If it doesn’t match, return an error (401 Unauthorized or 400 Bad Request).
6. If it matches, bcrypt-hash the new password and update the user’s `password_hash` in the database.
7. Invalidate other active sessions or tokens for this user if applicable (optional but recommended).
8. Return a success status.

Example implementation:

```go
// Route registration:
// router.POST("/api/users/:id/password", authMiddleware(), changePassword)

type ChangePasswordRequest struct {
    CurrentPassword string `json:"current_password" binding:"required"`
    NewPassword     string `json:"new_password" binding:"required,min=8"`
}

func changePassword(c *gin.Context) {
    userIDParam := c.Param("id")
    // Ensure the requesting user matches the target user ID (or has proper role)
    var req ChangePasswordRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request data"})
        return
    }
    // Find user and check current password
    var user User
    if err := db.First(&user, "id = ?", userIDParam).Error; err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
        return
    }
    // Compare provided current password with stored hash
    if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.CurrentPassword)); err != nil {
        // Wrong current password
        c.JSON(http.StatusUnauthorized, gin.H{"error": "Current password is incorrect"})
        return
    }
    // Hash the new password
    newHash, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to secure new password"})
        return
    }
    // Update password hash in DB
    user.PasswordHash = string(newHash)
    if err := db.Save(&user).Error; err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not update password"})
        return
    }
    // (Optional) Invalidate other sessions or tokens for this user, e.g., delete refresh tokens except current session
    
    c.JSON(http.StatusOK, gin.H{"message": "Password changed successfully"})
}
```

This handler uses `bcrypt.CompareHashAndPassword` to verify the old password before accepting the new one. We require the new password to be at least 8 characters (enforced via the binding tag or an explicit length check) – this complements the front-end checks. On success, we respond with a simple success message; the client can then inform the user. The actual `User` model would likely not be sent back here for security (no need to send hashes or sensitive info). If the current password was wrong, we return an error which the client will display as feedback. The `bcrypt.GenerateFromPassword` call produces a new salted hash which we store in place of the old hash. Thanks to the trigger on the `users` table, the `updated_at` field will reflect this change automatically.

One additional step to consider is session invalidation. If the app uses JWT tokens, changing the password does not automatically invalidate existing tokens issued before the change. A robust implementation might track token issuance or have a way to revoke tokens. Similarly, if using sessions stored in the `sessions` table, the backend might delete all sessions for that user (except perhaps the one used for this request) upon password change – forcing re-login on other devices. This wasn’t explicitly asked, but it’s a good security practice to mention while designing the change password functionality.

## Database Schema Considerations

Fortunately, **no major schema changes are required** to support profile editing or password updates – the existing `users` table already has the necessary columns. Fields like first name, last name, rank, and unit are present to store profile info, and the `password_hash` field stores the user’s encrypted password. The schema uses a sufficient length for passwords (`VARCHAR(255)` which can accommodate bcrypt hashes) and ensures emails and usernames are unique to avoid conflicts. There is also a trigger function that automatically updates the `updated_at` timestamp on any change to a user record, so auditing of when a profile was last modified is built-in.

If the current database was missing any profile fields, a migration would be needed – for example, an earlier version might not have had `rank` or `unit`, but according to the migration history those were added in an update. In the final schema, those fields exist, so users can edit them without issue. Similarly, no new columns are needed for changing passwords; we reuse `password_hash`. Just ensure that the code updating the password uses bcrypt or an equivalent secure hash function (as seen in the default admin seed using bcrypt) and that the application never stores plain-text passwords.

In summary, the **existing architecture supports these enhancements**. We mainly need to add front-end UI components and corresponding backend endpoints. By following the patterns already in place (e.g. form validation on the client, Gin route structure on the server, and the database schema constraints), the new **Edit Profile** and **Change Password** features can be integrated seamlessly into the HandReceipt app’s workflow. The result will be a more complete user account management experience, aligning with common user expectations while maintaining the security and consistency of the system’s design.

**Sources:**

* HandReceipt initial database schema (user fields and constraints)
* HandReceipt database triggers and seed data (audit of updates and password hashing)
