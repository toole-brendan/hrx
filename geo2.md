Great, I’ll walk you through exactly what to change in the latest version of the `toole-brendan/hrx` repo. I’ll go file by file and line by line across the backend (Go), frontend (React), iOS, and Android codebases. I’ll also include all required CLI commands and migration scripts where applicable to ensure the username field is fully removed and replaced with an email-based login system using rank + last name for identification.

I’ll get started and update you shortly.


## Backend (Go)

**1. Remove Username Field from User Model**
**File:** `backend/internal/domain/models.go` (User struct)

* **Delete** the `Username` field to eliminate username storage.
* **Old Code:**

  ```go
  type User struct {
      ID       uint      `gorm:"primaryKey"`
  -   Username string    `gorm:"uniqueIndex;not null"`
      Email    string    `gorm:"uniqueIndex;not null"`
      Password string    `gorm:"not null"`  // Hashed password
      Name     string    `gorm:"not null"`
      Rank     string    `gorm:"not null"`
      Unit     string    `gorm:""`
      // ... other fields ...
  }
  ```
* **New Code:**

  ```go
  type User struct {
      ID       uint      `gorm:"primaryKey"`
      Email    string    `gorm:"uniqueIndex;not null"`
      Password string    `gorm:"not null"`  // Hashed password
      Name     string    `gorm:"not null"`
      Rank     string    `gorm:"not null"`
      Unit     string    `gorm:""`
      // ... other fields unchanged ...
  }
  ```

  *Explanation:* The `Username` column is removed entirely. Users will be uniquely identified by their email, which remains a unique, non-null field. A database migration will drop the **username** column (see **Database Migration** below).

**2. Add Repository Method for Email Lookup**
**File:** `backend/internal/repository/repository.go` (Repository interface)

* **Add** a new method `GetUserByEmail(email string) (*domain.User, error)` and **remove** `GetUserByUsername` to reflect the new login mechanism.
* **Old Code (interface excerpt):**

  ```go
  type Repository interface {
      CreateUser(user *domain.User) error
      GetUserByID(id uint) (*domain.User, error)
      GetUserByUsername(username string) (*domain.User, error)
      // ... other methods ...
  }
  ```
* **New Code:**

  ```go
  type Repository interface {
      CreateUser(user *domain.User) error
      GetUserByID(id uint) (*domain.User, error)
  -   GetUserByUsername(username string) (*domain.User, error)
  +   GetUserByEmail(email string) (*domain.User, error)
      // ... other methods ...
  }
  ```

  *Explanation:* We drop username-based lookup and introduce `GetUserByEmail` for authentication. This change must be implemented in all repository implementations.

**3. Implement Email Lookup in Repositories**
**Files:**

* `backend/internal/repository/postgres_repository.go`
* `backend/internal/repository/gorm_repository.go`

In each repository implementation, add the new method to query by email, and remove or deprecate the username method. For example, in **PostgresRepository**:

```go
func (r *PostgresRepository) GetUserByEmail(email string) (*domain.User, error) {
    var user domain.User
    if err := r.db.Where("email = ?", email).First(&user).Error; err != nil {
        if errors.Is(err, gorm.ErrRecordNotFound) {
            return nil, err  // no user found
        }
        return nil, err
    }
    return &user, nil
}
```

Likewise, remove the body of `GetUserByUsername` or mark it unused. In **gormRepository** implement similarly with `.Where("email = ?", email)` instead of username.

**4. Accept Email in Login Request DTO**
**File:** `backend/internal/models/dto.go` (LoginRequest struct)

* **Modify** the login request to use an `Email` field instead of `Username`.
* **Old Code:**

  ```go
  type LoginRequest struct {
  -    Username string `json:"username" validate:"required,min=3,max=50"`
  +    Email    string `json:"email" validate:"required,email"`
       Password string `json:"password" validate:"required,min=8"`
  }
  ```

  *Explanation:* The server will expect a JSON body like `{"email": "...", "password": "..."}` for logins, with proper email validation.

**5. Update Auth Handler – Login**
**File:** `backend/internal/api/handlers/auth_handler.go` (Login handler)

* **Use Email for authentication:**

  * **Change** the credential binding and lookup to email.
  * **Replace** `GetUserByUsername` with `GetUserByEmail`.
  * **Modify** error messages referencing username.

* **Old Code (excerpt):**

  ```go
  if err := c.ShouldBindJSON(&credentials); err != nil { ... }
  // Authenticate user by username
  domainUser, err := h.repo.GetUserByUsername(credentials.Username)
  if err != nil {
      c.JSON(401, gin.H{"error": "Invalid credentials"})
      return
  }
  // ... password check ...
  ```

* **New Code:**

  ```go
  if err := c.ShouldBindJSON(&credentials); err != nil { ... }
  // Authenticate user by email
  domainUser, err := h.repo.GetUserByEmail(credentials.Email)
  if err != nil {
      c.JSON(401, gin.H{"error": "Invalid credentials"})
      return
  }
  // ... password check (unchanged) ...
  ```

  *Explanation:* The handler now finds users by email. A failed lookup or wrong password returns a generic **401 Unauthorized**. (Optional: adjust the failure JSON to `"Invalid email or password"` if desired – currently it uses `"Invalid credentials"` which is acceptable.).

* **Prepare login response without username:**
  After successful auth, the handler creates a `LoginResponse`. **Remove** any inclusion of username:

  ```go
      response := models.LoginResponse{
          User: models.UserDTO{
              ID:        domainUser.ID,
  -           Username:  domainUser.Username,
              Email:     domainUser.Email,
              FirstName: domainUser.Name,    // domain stores full name
              LastName:  "",                 // to be set below
              Rank:      domainUser.Rank,
              Unit:      domainUser.Unit,
              Role:      models.UserRole("user"),
              Status:    models.StatusActive,
              CreatedAt: domainUser.CreatedAt,
              UpdatedAt: domainUser.UpdatedAt,
          },
          // ... include tokens if any ...
      }
  ```

  Then **populate** first/last name properly. Since `domain.User.Name` holds the full name (e.g. `"Michael Rodriguez"`), split it into first and last name for the response:

  ```go
      // Split full name into first and last for response
      names := strings.SplitN(domainUser.Name, " ", 2)
      response.User.FirstName = names[0]
      if len(names) > 1 {
          response.User.LastName = names[1]
      }
  ```

  Finally, return the JSON response: `c.JSON(200, response)`.
  *Explanation:* The username is excluded from the response. Clients will receive the user’s `id, email, first_name, last_name, rank, unit, etc.` along with any tokens. We ensure `LastName` is filled so the UI can display rank + last name.

**6. Update Auth Handler – Register**
**File:** `backend/internal/api/handlers/auth_handler.go` (Register handler)

* **Remove username checks and usage:**

  * **Delete** the username uniqueness check and error:

    ```go
    ```
  * // Check if username already exists
  * \_, err := h.repo.GetUserByUsername(createUserInput.Username)
  * if err == nil {
  * ```
      c.JSON(400, gin.H{"error": "Username already exists"})
    ```
  * ```
      return
    ```
  * }

  ````
  - **Add** an email uniqueness check in its place:  
  ```go
    // Check if email already exists
    _, err := h.repo.GetUserByEmail(createUserInput.Email)
    if err == nil {
        c.JSON(400, gin.H{"error": "Email already exists"})
        return
    }
  ````

  * **Stop using Username when creating user:** when constructing the `domain.User` object for the new user, **omit** the Username field. Instead, fill only email and name:

    ```go
    domainUser := &domain.User{
    ```
  * ```
      Username: createUserInput.Username,
    Email:    createUserInput.Email,
    Password: string(hashedPassword),
    ```
  * ```
      Name:     createUserInput.FirstName + " " + createUserInput.LastName,
    ```

  - ```
      Name:     createUserInput.FirstName + " " + createUserInput.LastName,
    Rank:     createUserInput.Rank,
    Unit:     createUserInput.Unit,
    // ... Role, etc.
    ```

    }

    ```
    (Since `Username` is removed from the struct, any attempt to set it will be a compile error – simply delete that line.)  
    ```

  * **Build response without username:** Similar to login, exclude username in the returned `LoginResponse`. Use the provided first and last name directly:

    ```go
    response := models.LoginResponse{
        User: models.UserDTO{
            ID:        domainUser.ID,
    ```
  * ```
        Username:  domainUser.Username,
        Email:     createUserInput.Email,
        FirstName: createUserInput.FirstName,
        LastName:  createUserInput.LastName,
        Rank:      createUserInput.Rank,
        Unit:      createUserInput.Unit,
        Role:      models.UserRole(createUserInput.Role),
        Status:    models.StatusActive,
        CreatedAt: domainUser.CreatedAt,
        UpdatedAt: domainUser.UpdatedAt,
    },
    // tokens if any...
    ```

    }

    ```
    ```

  *Explanation:* New users are now created **without** a username. The **email must be unique**; a duplicate email triggers a **400** error `"Email already exists"`. The client receives the new user’s data (with separate first/last name) on successful registration.

**7. Update User Profile Handler**
**File:** `backend/internal/api/handlers/user_handler.go` (UpdateUserProfile)

* **Remove username from profile responses:** When returning the updated profile, stop including username. Instead, return the updated email and name fields. For example:

  ```go
  response := models.UserDTO{
      ID:        user.ID,
  -   Username:  user.Username,
      Email:     user.Email,
  -   FirstName: user.Name,  // Since domain.User only has Name
  -   LastName:  "",
  +   FirstName: firstNamePart(user.Name),
  +   LastName:  lastNamePart(user.Name),
      Rank:      user.Rank,
      Unit:      user.Unit,
      CreatedAt: user.CreatedAt,
      UpdatedAt: user.UpdatedAt,
  }
  ```

  Here, `firstNamePart`/`lastNamePart` represent splitting the `Name` field (similar to login above) so that the response provides a separate last name. The result JSON has no `"username"` field.
* **No username updates allowed:** Notice we did **not** add any handling for a username in the update request (and we removed it from the DTO). Users cannot update a username anymore, since it’s deprecated. This keeps the profile update logic simpler.

**8. Update Default Admin User Creation**
**File:** `backend/internal/platform/database/database.go` (`CreateDefaultUser`)

* **Remove** the use of a username for the default admin. Provide an email instead.
* **Old Code:**

  ```go
  if count == 0 {
      defaultUser := domain.User{
  -        Username: "admin",
          Password: "<hashed>", // "password"
          Name:     "Admin User",
          Rank:     "System Administrator",
          Email:    "", // (was missing in old code)
      }
      db.Create(&defaultUser)
      log.Println("Created default admin user")
  }
  ```
* **New Code:**

  ```go
  if count == 0 {
      defaultUser := domain.User{
          // Username removed
          Email:    "admin@handreceipt.com",
          Password: "<hashed>", // "password" hashed (for initial setup only)
          Name:     "Admin User",
          Rank:     "System Administrator",
          Unit:     "",
      }
      db.Create(&defaultUser)
      log.Println("Created default admin user")
  }
  ```

  *Explanation:* We supply a placeholder email (e.g. **[admin@handreceipt.com](mailto:admin@handreceipt.com)**) since Email is required. The default user no longer has a username. (For better security, consider forcing an admin to change this default password on first login, but that’s outside our scope.)

## Frontend (Web – React)

**1. Use Email in Login Page**
**File:** `web/src/pages/Login.tsx`

* **Replace** the username field with an email field.

  * In the Zod schema (`loginSchema`): change `username` to `email` with proper validation.
  * **Old Schema:**

    ```tsx
    const loginSchema = z.object({
    ```
  * ```
    username: z.string().min(1, "Username is required"),
    ```

  - ```
    email: z.string().min(1, "Email is required").email("Invalid email address"),
    password: z.string().min(1, "Password is required"),
    ```

    });

    ```
    ```

  * **Component State:** if a default values object is used, rename `username: ""` to `email: ""` accordingly.
  * **Form Field:** change the form field name and label:

    ```tsx
    <FormField
    ```
  * ```
    name="username"
    ```

  - ```
    name="email"
    render={({ field }) => (
        <FormItem>
    ```

  * ```
            <FormLabel>Username</FormLabel>
    ```

  - ```
            <FormLabel>Email</FormLabel>
            <FormControl>
    ```

  * ```
                <Input {...field} placeholder="" /* ... */ />
    ```

  - ```
                <Input type="email" {...field} placeholder="" /* ... */ />
            </FormControl>
        </FormItem>
    )}
    ```

    />

    ```
    Ensure the `Input` has `type="email"` for proper mobile keyboards.  
    ```

  * **Submission:** call `await login(data.email, data.password)` instead of `data.username`. In the component’s `onSubmit`:

    ```tsx
    const onSubmit = async (data: LoginFormValues) => {
        setIsLoading(true);
        try {
    ```
  * ```
        await login(data.username, data.password);
    ```

  - ```
        await login(data.email, data.password);
        // ... success toast and redirect ...
    } catch (error) {
        toast({ title: "Login Failed", 
    ```

  * ```
              description: "Invalid username or password", 
    ```

  - ```
              description: "Invalid email or password",
              variant: "destructive" });
    } finally { setIsLoading(false); }
    ```

    };

    ```
    *Explanation:* The login form now only asks for **Email** and **Password**. The error message is adjusted accordingly. The `useAuth()` context `login` function signature will be updated to `(email, password)` in AuthContext (see below).

    ```

* **Dev Login Shortcut:** If there is a development/test login trigger (like tapping the logo multiple times), update it to use an email. For example, in the `performDevLogin()` function:

  ```tsx
  form.setValue("email", "michael.rodriguez@handreceipt.com");
  form.setValue("password", "password123");
  await login("michael.rodriguez@handreceipt.com", "password123");
  // ... toast success ...
  ```

  Use a valid-looking email for the test user (e.g., **[michael.rodriguez@handreceipt.com](mailto:michael.rodriguez@handreceipt.com)** instead of just `"michael.rodriguez"`).

* **Auth Context login method:** In `web/src/contexts/AuthContext.tsx`, change the context and implementation to accept email:

  ```tsx
  interface AuthContextType {
  -   login: (username: string, password: string) => Promise<void>;
  +   login: (email: string, password: string) => Promise<void>;
      // ...
  }
  // ...
  const login = async (email: string, password: string) => {
      // ... (development mode branch unchanged) ...
      const response = await fetch(`${API_BASE_URL}/api/auth/login`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
  -       body: JSON.stringify({ username, password }),
  +       body: JSON.stringify({ email, password }),
          credentials: 'include',
      });
      if (response.ok) {
          const data = await response.json();
  -       setUser(data.user);
  +       // Format user name for display as "Rank LastName"
  +       const user = data.user;
  +       user.name = `${user.rank} ${user.lastName}`;
  +       setUser(user);
          setIsAuthenticated(true);
      } else {
          // ... handle error ...
      }
  };
  ```

  *Explanation:* The context now sends `email` in the request payload. We also post-process the returned user object: setting `user.name = "<Rank> <LastName>"` ensures any component using `user.name` (like avatars or headings) will display the proper format (e.g. `"CPT Rodriguez"`).

* **TopNavBar / Avatar:** No username changes are needed here because we’ve provided a `name` for the user. The avatar will use `user.name` which is now e.g. `"CPT Rodriguez"`, and initials will be derived from that (`"CR"`). If we preferred to derive initials differently, we could adjust `userInitials` to use the last name initial, but using the combined name works with the existing logic.

**2. Remove Username from Registration Page**
**File:** `web/src/pages/Register.tsx`

* **Delete** the username input field entirely and use only email for new accounts.

  * **Schema:** drop the username requirement.

    ```tsx
    const registerSchema = z.object({
    ```
  * ```
    username: z.string().min(3, "Username must be at least 3 characters"),
    email: z.string().email("Invalid email address"),
    password: z.string().min(8, "Password must be at least 8 characters"),
    confirmPassword: z.string(),
    first_name: z.string().min(2, "First name is required"),
    last_name:  z.string().min(2, "Last name is required"),
    rank:       z.string().min(1, "Rank is required"),
    unit:       z.string().min(1, "Unit is required"),
    ```

    }).refine(...passwords match...);

    ```
    Remove any reference to `username` in `defaultValues` as well:contentReference[oaicite:9]{index=9}:contentReference[oaicite:10]{index=10}. 
    ```
  * **JSX Form:** remove the entire `<FormField name="username">...</FormField>` block. The email field (which was already present) will remain. For example, before and after:

    ```tsx
    {/* Name fields in a grid */}
    <div className="grid grid-cols-2 gap-4">
      ... First Name ... Last Name ...
    </div>
    ```
  * {/\* Username field - remove this block \*/}
  * <FormField name="username"> 
  * <FormLabel>Username</FormLabel>
  * \<Input {...field} />
  * </FormField>
    {/* Email field (kept) */}
    <FormField name="email">
       <FormLabel>Email</FormLabel>
       <Input type="email" {...field} />
    </FormField>
    ```  
    After removal, users will provide first name, last name, **email**, password, etc., but **not username**. The UI layout will naturally adjust (one less field).  
  * **Submission:** remove `username` from the payload sent to the API. In the `fetch` call for registration:

    ```tsx
    const response = await fetch(API_BASE_URL + "/api/auth/register", {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
    ```
  * ```
        username: data.username,
        email:    data.email,
        password: data.password,
        first_name: data.first_name,
        last_name:  data.last_name,
        rank:       data.rank,
        unit:       data.unit,
        role: "user"
    }),
    credentials: 'include',
    ```

    });

    ```
    Now we only send email and the other required fields:contentReference[oaicite:11]{index=11}. The backend will create the user without a username.  
    ```
  * **UI Messages:** If the backend returns an error that the email exists, it will come as `{ error: "Email already exists" }`. The code already throws `error.message`, which will yield that string. The toast in the catch will display `"Email already exists"` as the description (no change needed except that it no longer says "Username or email"). If we want, we can adjust the fallback in the catch:

    ```tsx
    throw new Error(error.message || 'Registration failed');
    ```

    (This is already in place.)

* **AuthContext (registration flow):** If the app uses the login response after registration (some apps auto-login new users or update state), ensure it handles the new format. In this app, after successful registration, the code shows a toast and redirects to login. No changes needed there, aside from making sure the `LoginResponse` handling (if any) doesn’t expect a username field.

**3. Profile & User Display**
With usernames gone, any UI that displayed or used usernames should be updated:

* **User Profile Page:** (`web/src/pages/Profile.tsx`) – It currently shows `user.name` as the heading, which after our changes is `"Rank LastName"` (since we set `user.name` in AuthContext). This is already correct for the requirement. No explicit username field is shown on the profile page, so nothing to remove there.
* **Settings/Account Pages:** If there were a section showing “Username” or allowing username change, it should be removed. Scanning the code, there is no dedicated username field in settings, so we’re fine.
* **User Management Listing:** (`web/src/pages/UserManagement.tsx`) – This uses a `name` property (last name, first name format) for display and does not reference username at all. It’s already effectively showing “Last, First” with rank separate, which is acceptable. We could consider showing rank and last name only, but since this is a management view with full names, it’s fine to leave as is (the name there is likely “Last, First”). No code change needed.

**4. Remove any Remaining Username References:**
Search the React codebase for `username` to ensure we haven’t missed anything. For example, ensure no API calls are still using `username`: the `useAuth` context covers login; registration we updated; other API calls (like searching users) use names or IDs. Remove any prop or state named `username` if it’s no longer used. After the above changes, the React app no longer deals with usernames at all.

## Mobile – iOS (Swift)

**1. Login with Email Only**

* **Login View:**
  **File:** `ios/HandReceipt/Views/LoginView.swift`

  * **Replace** the “Username” text field with an “Email” field.

    ```swift
    VStack(spacing: 16) {
    ```
  * ```
    UnderlinedTextField(
    ```
  * ```
        label: "Username",
    ```
  * ```
        text: $viewModel.username,
    ```
  * ```
        placeholder: "Enter your username",
    ```
  * ```
        textContentType: .username,
    ```
  * ```
        keyboardType: .asciiCapable,
    ```
  * ```
        autocapitalization: .none
    ```
  * ```
    )
    ```

  - ```
    UnderlinedTextField(
    ```
  - ```
        label: "Email",
    ```
  - ```
        text: $viewModel.email,
    ```
  - ```
        placeholder: "Enter your email",
    ```
  - ```
        textContentType: .emailAddress,
    ```
  - ```
        keyboardType: .emailAddress,
    ```
  - ```
        autocapitalization: .none
    ```
  - ```
    )
    UnderlinedSecureField(
        label: "Password",
        text: $viewModel.password,
        placeholder: "Enter your password",
        textContentType: .password
    )
    ```

    }

    ```
    *Changes:* We bound the text field to a new `$viewModel.email` property (see ViewModel changes below). The `textContentType` is set to `.emailAddress` for better auto-fill, and keyboard type to email. This removes the username from the UI entirely – users will enter their email in this field.  

    ```

  * **Error messages:** If the LoginView displayed any explicit error about username, update it. In this app, the validation and error display are handled in the **ViewModel**, which we address next. The UI just shows `errorMessage` text, which will be updated to reference email in the ViewModel.

* **Login ViewModel:**
  **File:** `ios/HandReceipt/ViewModels/LoginViewModel.swift`

  * **Introduce an email property:**

    ```swift
    class LoginViewModel: ObservableObject {
    ```
  * ```
    @Published var username = ""
    ```

  - ```
    @Published var email = ""
    @Published var password = ""
    @Published var loginState: LoginState = .idle
    @Published var canAttemptLogin = false
    // ...
    ```

    }

    ````
    Replace all uses of `username` with `email`. For example, in the Combine validation:  
    ```swift
    Publishers.CombineLatest($email, $password)
        .map { email, password -> Bool in
            let canLogin = !email.trimmingCharacters(in: .whitespaces).isEmpty &&
                           !password.isEmpty
            return canLogin
        }
        .assign(to: &$canAttemptLogin)
    ````

    and in the `sink` where it resets state on input change, track `$email` instead of `$username`.

  * **Attempt login with email:** In `attemptLogin()`, construct credentials using email:

    ```swift
    func attemptLogin() {
        // ... validation ...
        loginState = .loading
        Task {
            do {
    ```
  * ```
            let credentials = LoginCredentials(username: username, password: password)
    ```

  - ```
            let credentials = LoginCredentials(email: email, password: password)
            let response = try await apiService.login(credentials: credentials)
            debugPrint("LoginViewModel: Login Successful: User \(response.user.email ?? "<no email>") (ID: \(response.user.id))")
            self.loginState = .success(response)
        } catch let error as APIService.APIError {
            // handle known API errors
            if case .badRequest(let message) = error {
    ```

  * ```
                self.loginState = .failed(message ?? "Invalid username or password.")
    ```

  - ```
                self.loginState = .failed(message ?? "Invalid email or password.")
            } else {
                self.loginState = .failed(error.localizedDescription)
            }
        } catch {
            self.loginState = .failed("An unexpected error occurred during login.")
        }
    }
    ```

    }

    ```
    *Explanation:* Now the view model sends an `email` and password to the API. We adjusted the error message for bad credentials to say **"Invalid email or password."** (The backend returns 401 with `"Invalid credentials"`, which we interpret as this message to the user.) We also updated the debug print to show the user’s email on success:contentReference[oaicite:16]{index=16}:contentReference[oaicite:17]{index=17}.

    ```

  * **Equatable LoginState:** If present, update any equality checks that used username. In `LoginState ==` (in this file), change the success comparison to use a different property or remove the username check. For instance:

    ```swift
    case (.success(let lResp), .success(let rResp)):
    ```
  * ```
    return lResp.userId == rResp.userId && lResp.user.username == rResp.user.username
    ```

  - ```
    return lResp.user.id == rResp.user.id
    ```

    ```
    Using user ID alone is enough to compare identity of login responses. This prevents trying to access a now-removed username.

    ```

* **Auth API Models:**
  **File:** `ios/HandReceipt/Models/AuthModels.swift`

  * **LoginCredentials struct:** change to use email.

    ```swift
    public struct LoginCredentials: Encodable {
    ```
  * ```
    public let username: String
    ```

  - ```
    public let email: String
    public let password: String
    public init(email: String, password: String) {
    ```

  * ```
        self.username = username
    ```

  - ```
        self.email = email
        self.password = password
    }
    ```

    }

    ```
    *Explanation:* The JSON sent will now have an `"email"` field instead of `"username"`.  

    ```

  * **LoginResponse.User struct:** remove `username` and make sure email is included.

    ```swift
    public struct User: Codable {
        public let id: Int
        public let uuid: String?
    ```
  * ```
    public let username: String
    ```

  - ```
    // username removed
    public let email: String?
    public let firstName: String?
    public let lastName: String?
    public let rank: String
    public let unit: String?
    public let role: String?
    public let status: String?
    // ...
    ```

  * ```
    public var name: String {
    ```
  * ```
        if let firstName = firstName, let lastName = lastName {
    ```
  * ```
            return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    ```
  * ```
        } else if let firstName = firstName {
    ```
  * ```
            return firstName
    ```
  * ```
        } else if let lastName = lastName {
    ```
  * ```
            return lastName
    ```
  * ```
        } else {
    ```
  * ```
            return username
    ```
  * ```
        }
    ```
  * ```
    }
    ```

  - ```
    public var name: String {
    ```
  - ```
        // Prefer rank + last name for display if available
    ```
  - ```
        if let rank = rankOptional(), let last = lastName, !rank.isEmpty && !last.isEmpty {
    ```
  - ```
            return "\(rank) \(last)"
    ```
  - ```
        } else if let first = firstName, let last = lastName {
    ```
  - ```
            return "\(first) \(last)".trimmingCharacters(in: .whitespaces)
    ```
  - ```
        } else if let last = lastName {
    ```
  - ```
            return last
    ```
  - ```
        } else if let first = firstName {
    ```
  - ```
            return first
    ```
  - ```
        } else {
    ```
  - ```
            return ""
    ```
  - ```
        }
    ```
  - ```
    }
     // CodingKeys: remove .username
     enum CodingKeys: String, CodingKey {
         case id, uuid,
    ```

  * ```
         username,
         email,
         firstName = "first_name",
         lastName  = "last_name",
         rank, unit, role, status
     }
     // init(from decoder: ...) also remove decoding username
    ```

    }

    ```
    *Explanation:* We eliminated the `username` field entirely from the user model. We also updated the computed `name` property to prioritize showing **Rank LastName** when possible. Now, `user.name` will return `"CPT Rodriguez"` for example (because rank is always provided in our app). If rank or last name is missing, it falls back to first/last as appropriate. The fallback no longer uses `username` (which is gone). The decoding logic (`init(from:)`) should use `decodeIfPresent` for new optional fields and no longer expect a username key, to align with the backend response:contentReference[oaicite:18]{index=18}:contentReference[oaicite:19]{index=19}.

    ```
  * **RegisterCredentials struct:** remove username.

    ```swift
    public struct RegisterCredentials: Encodable {
    ```
  * ```
    public let username: String
    public let email: String
    public let password: String
    public let first_name: String
    public let last_name: String
    public let rank: String
    public let unit: String
    public let role: String
    public init(email: String, password: String,
    ```
  * ```
               username: String,
               first_name: String, last_name: String,
               rank: String, unit: String, role: String = "user") {
    ```
  * ```
        self.username = username
        self.email = email
        self.password = password
        self.first_name = first_name
        self.last_name = last_name
        self.rank = rank
        self.unit = unit
        self.role = role
    }
    enum CodingKeys: String, CodingKey {
    ```
  * ```
        case username, email, password
    ```

  - ```
        case email, password
        case first_name, last_name, rank, unit, role
    }
    ```

    }

    ```
    Now the registration JSON will omit username (matching our React frontend). The backend expects no username field, so this is correct.  

    ```

* **API Service:**
  **File:** `ios/HandReceipt/Services/APIService.swift`

  * **Login request:** When encoding credentials, it now includes email. The debug log should be adjusted:

    ```swift
    public func login(credentials: LoginCredentials) async throws -> LoginResponse {
    ```
  * ```
    debugPrint("Attempting to login user: \(credentials.username)")
    ```

  - ```
    debugPrint("Attempting to login user: \(credentials.email)")
    // ... encode and send ...
    let response = try await performRequest(request: request) as LoginResponse
    ```

  * ```
    debugPrint("Login successful for user: \(response.user.username)")
    ```

  - ```
    debugPrint("Login successful for user: \(response.user.email ?? "<no email>")")
    return response
    ```

    }

    ```
    ```

  * **Register request:** Similarly, remove username from logs and error messages:

    ```swift
    public func register(credentials: RegisterCredentials) async throws -> LoginResponse {
    ```
  * ```
    debugPrint("Attempting to register user: \(credentials.username)")
    ```

  - ```
    debugPrint("Attempting to register user: \(credentials.email)")
    // ... encode and send ...
    do {
        let response = try await performRequest(request: request) as LoginResponse
        // ... store tokens ...
    ```

  * ```
        debugPrint("Registration successful for user: \(response.user.username)")
    ```

  - ```
        debugPrint("Registration successful for user: \(response.user.email ?? response.user.lastName ?? "user")")
        return response
    } catch let error as APIError {
        if case .badRequest(let message) = error {
    ```

  * ```
            throw APIError.badRequest(message: message ?? "Username or email already exists")
    ```

  - ```
            throw APIError.badRequest(message: message ?? "Email already exists")
        }
        throw error
    }
    ```

    }

    ```
    *Explanation:* We now identify users by email in debug output. On a 409 conflict during registration, we assume it’s an email conflict (since username is gone) and throw **"Email already exists"** if no specific message came from the server:contentReference[oaicite:20]{index=20}:contentReference[oaicite:21]{index=21}. The UI will display that via the ViewModel’s error handling (which we set to show server-provided messages).

    ```

* **Auth Manager:**
  **File:** `ios/HandReceipt/Services/AuthManager.swift`
  The AuthManager uses `LoginResponse.user`. We removed `username` from there, but we did provide `email`, `firstName`, `lastName`, etc. The code stores `currentUser = response.user` and uses it throughout. This should continue to work. For example, in `ProfileView` the code checks `if let user = authManager.currentUser`:

  ```swift
  // ProfileView.swift (User Information section)
  if let user = authManager.currentUser {
      ProfileInfoRow(label: "NAME", value: "\(user.rank) \(user.name)", icon: "person")
      ProfileInfoRow(label: "USERNAME", value: "@\(user.username)", icon: "at")
      // ...
  }
  ```

  We need to remove that **USERNAME** row.

**2. Remove Username from Profile UI**

* **ProfileView (SwiftUI):**
  **File:** `ios/HandReceipt/Views/Profile/ProfileView.swift`

  * **Delete** the username row from the profile information section.

    ```swift
    ProfileInfoRow(
        label: "NAME",
        value: "\(user.rank) \(user.name)",
        icon: "person"
    )
    ProfileDivider()
    ```
  * ProfileInfoRow(
  * ```
    label: "USERNAME",
    ```
  * ```
    value: "@\(user.username)",
    ```
  * ```
    icon: "at",
    ```
  * ```
    valueFont: .mono
    ```
  * )
  * ProfileDivider()
    ProfileInfoRow(
    label: "USER ID",
    value: "#(user.id)",
    icon: "number",
    valueFont: .mono
    )

    ```
    After removal, the **Name** row shows, and directly below it the **User ID** row (and Rank row). We no longer show a username at all:contentReference[oaicite:22]{index=22}:contentReference[oaicite:23]{index=23}.  
    ```
  * **Adjust Name display if needed:** Currently, the **Name** row is constructed as `user.rank + " " + user.name`. With our changes, `user.name` returns either `"First Last"` or just last name (or rank+last if rank wasn’t included separately). Given we set it to prefer rank + last name, there’s a slight overlap: here they prepend rank again. We should ensure it doesn’t double up. One easy fix is to display **rank + last name** explicitly and avoid first name:

    ```swift
    ProfileInfoRow(
        label: "NAME",
    ```
  * ```
    value: "\(user.rank) \(user.name)",
    ```

  - ```
    value: "\(user.rank) \(user.lastName ?? "")",
    icon: "person"
    ```

    )

    ```
    Now, if the user is *CPT Michael Rodriguez*, this will show “CPT Rodriguez” as desired. (If `lastName` is nil, it just shows rank.) This overrides any inclusion of first name in the profile display, meeting the requirement that the user is identified by rank + last name in the UI.  

    ```
* **Other UI Components:**
  Search for any usage of `user.username` or `username` in SwiftUI views. For example:

  * In **ContentView\.swift**, there are debug prints after login:

    ```swift
    debugPrint("Login successful for user \(loginResponse.user.username)")
    // ... AuthManager.login(response) ...
    debugPrint("Authenticated as \(authManager.currentUser?.username ?? "unknown")")
    ```

    These can be updated to use `user.email` or simply removed (since they are debug). For accuracy:

    ```swift
    debugPrint("Login successful for user \(loginResponse.user.email ?? loginResponse.user.lastName ?? "unknown")")
    debugPrint("Authenticated as \(authManager.currentUser?.email ?? authManager.currentUser?.lastName ?? "unknown")")
    ```

    This is optional since it doesn’t affect functionality (just keeping logs consistent).

  * In **Transfer-related views** (e.g., `OfferPropertyView.swift`, `UserSelectionView.swift`), if any, ensure they don’t display `username`. Likely they use `UserSummary.name`. Our `UserSummary.name` computed property in models will now also prefer rank + last name (we should apply a similar change as we did for `User.name`). In **Models.swift** for `UserSummary`:

    ```swift
    public struct UserSummary { 
        public let username: String 
        public let rank: String? 
        public let lastName: String? 
        public let firstName: String? 
        // ...
        public var name: String {
    ```

  * ```
        if let firstName = firstName, let lastName = lastName {
    ```

  * ```
            return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    ```

  * ```
        } else if let firstName = firstName {
    ```

  * ```
            return firstName
    ```

  * ```
        } else if let lastName = lastName {
    ```

  * ```
            return lastName
    ```

  * ```
        } else {
    ```

  * ```
            return username
    ```

  * ```
        }
    ```

  - ```
        if let rank = rank, let last = lastName, !rank.isEmpty && !last.isEmpty {
    ```
  - ```
            return "\(rank) \(last)"
    ```
  - ```
        } else if let last = lastName, let first = firstName, !last.isEmpty && !first.isEmpty {
    ```
  - ```
            return "\(first) \(last)"
    ```
  - ```
        } else if let last = lastName {
    ```
  - ```
            return last
    ```
  - ```
        } else if let first = firstName {
    ```
  - ```
            return first
    ```
  - ```
        } else {
    ```
  - ```
            return ""
    ```
  - ```
        }
    ```

  }

  ```
  And remove the `username` property from `UserSummary` entirely (since it’s not needed). Now any UI that calls `userSummary.name` will get “Rank Last” when both are present. This will apply to things like transfer offer displays, etc., making sure that even in lists of users the rank+last is shown.  
  ```

After these iOS changes, the app will exclusively use emails for login/registration. The profile and any user displays will favor rank and last name, and nothing in the app should mention or require a username.

## Mobile – Android (Kotlin)

**1. Login with Email Only**

* **Login ViewModel:**
  **File:** `android/app/src/main/java/com/example/handreceipt/viewmodels/LoginViewModel.kt`

  * **Use email instead of username:**

    ```kotlin
    class LoginViewModel @Inject constructor(...): ViewModel() {
    ```
  * private val \_username = MutableStateFlow("")
  * val username: StateFlow<String> = \_username.asStateFlow()

  - private val \_email = MutableStateFlow("")
  - val email: StateFlow<String> = \_email.asStateFlow()
    private val \_password = MutableStateFlow("")
    val password: StateFlow<String> = \_password.asStateFlow()
    // ...
    fun onUsernameChange(input: String) {

  * ```
      _username.value = input
    ```

  - ```
      _email.value = input
      // reset error state if needed ...
    ```

    }
    fun canAttemptLogin(): Boolean {

  * ```
      return username.value.isNotBlank() && password.value.isNotBlank()
    ```

  - ```
      return email.value.isNotBlank() && password.value.isNotBlank()
    ```

    }
    fun attemptLogin() {
    if (!canAttemptLogin()) {

  * ```
          _eventFlow.emit(LoginEvent.ShowSnackbar("Username and password cannot be empty."))
    ```

  - ```
          _eventFlow.emit(LoginEvent.ShowSnackbar("Email and password cannot be empty."))
          return
      }
      if (_screenState.value == LoginScreenState.Loading) return
      _screenState.value = LoginScreenState.Loading
    ```

  * ```
      val credentials = LoginCredentials(username.value.trim(), password.value)
    ```

  - ```
      val credentials = LoginCredentials(email.value.trim(), password.value)
      viewModelScope.launch {
          try {
              val response = service.login(credentials)
              if (response.isSuccessful) {
                  val loginResponse = response.body()
                  if (loginResponse != null) {
    ```

  * ```
                      println("Login Successful: User ${loginResponse.username} (ID: ${loginResponse.userId})")
    ```

  - ```
                      println("Login Successful: User ID ${loginResponse.userId}")
                      _screenState.value = LoginScreenState.Success(loginResponse)
                  }
              } else {
                  when(response.code()) {
    ```

  * ```
                        401 -> "Invalid username or password."
    ```

  - ```
                        401 -> "Invalid email or password."
                          else -> "Login failed (Code: ${response.code()})."
                  }.also { msg ->
                      _eventFlow.emit(LoginEvent.ShowSnackbar(msg))
                  }
                  println("Login Error: ${response.code()} - ${response.errorBody()?.string()}")
                  _screenState.value = LoginScreenState.Idle
              }
          } catch (e: HttpException) {
              _eventFlow.emit(LoginEvent.ShowSnackbar("Network error: ${e.message}"))
              _screenState.value = LoginScreenState.Idle
          }
      }
    ```

    }
    }

    ```
    *Explanation:* We renamed the `_username` state flow to `_email` and updated all logic to use `_email`. The snackbar messages now refer to email. The `LoginCredentials` object is constructed with the email. On failure 401, we show “Invalid email or password.” instead of mentioning username:contentReference[oaicite:24]{index=24}:contentReference[oaicite:25]{index=25}. The success log now omits username (since our LoginResponse will change, see below).  

    ```

  * **UI Binding (LoginScreen):**
    Ensure that the UI is bound to the new email state. For example, in `LoginScreen.kt` (if it exists), the text field that was bound to `loginViewModel.username` should bind to `loginViewModel.email`. Also adjust the label to "Email". This might be something like:

    ```kotlin
    OutlinedTextField(
        value = loginViewModel.email.collectAsState().value,
        onValueChange = { loginViewModel.onUsernameChange(it) /* rename to onEmailChange */ },
        label = { Text("Email") },
        keyboardOptions = KeyboardOptions.Default.copy(keyboardType = KeyboardType.Email)
    )
    ```

    We don’t have the exact code here, but conceptually replace usage of `username` with `email`.

* **Auth API Models:**
  **File:** `android/app/src/main/java/com/example/handreceipt/data/model/models.kt`

  * **LoginCredentials:** use email.

    ```kotlin
    data class LoginCredentials(
    ```
  * val username: String,

  - val email: String,
    val password: String
    )

  ````
  This will serialize to JSON with `"email"` automatically (because the property name is email).  

  - **LoginResponse:** adjust to match backend’s new response. The backend now returns a JSON containing a `user` object (with details) and possibly tokens. We should reflect that in the data model for proper parsing. For example, redefine `LoginResponse` to include the nested user DTO:  
  ```kotlin
  - data class LoginResponse(
  -     @SerializedName("userId") val userId: UUID,
  -     val username: String,
  -     val role: String?,
  -     val message: String?
  - )
  + data class LoginResponse(
  +     val accessToken: String?,      // JWT access token if present
  +     val refreshToken: String?,
  +     val expiresAt: String?,        // or Date, if configured with a custom adapter
  +     val user: User
  + )
  data class User(
      val id: UUID,
  -     val username: String,
      val email: String,
      val firstName: String?,
      val lastName: String?,
      val rank: String?,
      val role: String?
  )
  ````

  Note: We add `email` to `User` and remove `username`. If the app isn’t using `UUID` for user ID (the backend’s ID is likely an integer), adjust types accordingly (perhaps use `Int` or `Long` for id instead of UUID). The key is to match the JSON structure. The backend’s `LoginResponse` JSON looks like:

  ```json
  {
    "access_token": "...", 
    "refresh_token": "...",
    "expires_at": "...",
    "user": {
       "id": 123,
       "uuid": "<uuid>",     (if provided)
       "email": "michael.rodriguez@...",
       "first_name": "Michael",
       "last_name": "Rodriguez",
       "rank": "CPT",
       "unit": "...",
       "role": "user",
       "status": "active",
       "created_at": "...",
       "updated_at": "..."
    }
  }
  ```

  We should update our data classes to capture what we need. At minimum, include `email, firstName, lastName, rank` in `User`. (We removed `username` entirely.)

  *Impact:* With this change, places that accessed `loginResponse.username` or `loginResponse.userId` will break. We will fix those next.

* **AuthViewModel and Usage:**
  **File:** `android/app/src/main/java/com/example/handreceipt/viewmodels/AuthViewModel.kt`

  * Wherever we logged or used `response.body()?.username` or `userId`, change to use the nested user. For instance:

    ```kotlin
    if (response.isSuccessful && response.body() != null) {
        _currentUser.value = response.body()
        _isAuthenticated.value = true
    ```
  * ```
    println("AuthViewModel: Session check successful for ${response.body()?.username}")
    ```

  - ```
    println("AuthViewModel: Session check successful for ${response.body()?.user?.email}")
    ```

    } else { ... }
    // ...
    if (response.isSuccessful && response.body() != null) {
    \_currentUser.value = response.body()
    \_isAuthenticated.value = true

  * ```
    println("AuthViewModel: Login successful for ${response.body()?.username}")
    ```

  - ```
    println("AuthViewModel: Login successful for ${response.body()?.user?.email}")
    ```

    }

    ```
    These debug prints now use email. If email is not set, we could use lastName as fallback.  

    ```

  * The `currentUser` is now a `LoginResponse` containing a `user`. In the UI, if we ever display current user info, we’ll need to navigate into `.user`. For example, if there was a welcome message using `authViewModel.currentUser.username`, it should use `authViewModel.currentUser.user.rank` and `.lastName`. Suppose we had a text somewhere like:

    ```kotlin
    Text("Welcome, ${authViewModel.currentUser.value?.username}")
    ```

    It should be changed to:

    ```kotlin
    Text("Welcome, ${authViewModel.currentUser.value?.user?.rank.orEmpty()} ${authViewModel.currentUser.value?.user?.lastName.orEmpty()}")
    ```

    This displays rank and last name of the logged-in user. (If not using LiveData/StateFlow binding directly in Compose, fetch the values accordingly.)

* **Remove Username in UI:**
  Search the Android app for any user-facing text showing username. Likely places:

  * Perhaps a profile screen or navigation drawer header. If there’s a UI showing `@username`, change it to show email or remove it.

  * The user selection lists (if any): The `UserSummary` data class had a `username`. We removed it. If e.g. `UserSelectionScreen` shows a list of users by username, change it to display `"${user.rank} ${user.lastName}"`. For instance, if it was:

    ```kotlin
    Text(userSummary.username)
    ```

    use:

    ```kotlin
    Text("${userSummary.rank.orEmpty()} ${userSummary.lastName.orEmpty()}")
    ```

    Possibly combine first name if needed, but the requirement is to emphasize rank + last name.

  * **Transfers or notifications:** if any string templates included username, switch them to use rank/last. For example, a transfer notification "SGT Adams sent you a transfer request" was likely already using name fields, but double-check.

After these changes, the Android app uses email for login and never displays or requires a username. The `LoginResponse` parsing aligns with the updated backend, and any UI now identifies users by rank and last name.

## Database Migration and CLI Instructions

With code changes done, we must apply a **schema migration** to drop the `username` column from the **users** table and ensure email is the sole login identifier:

**Migration Script (SQL):** Create a new migration file (e.g., `sql/migrations/009_remove_username_column.sql`) with:

```sql
ALTER TABLE users
DROP COLUMN username;
```

This will remove the Username field and its unique index from the database. The Email field remains with its unique constraint (so existing usernames that might conflict with emails aren’t an issue – emails were already unique).

If the `users` table has any triggers or functions depending on the username (unlikely in this app), those should be updated or dropped accordingly. In our case, we simply remove the column.

**Running the Migration:**

* If you use the Golang Migrate CLI as described in the project’s **MIGRATION\_GUIDE**, you can add this migration and run:

  ```bash
  # Assuming migrate tool is configured and DATABASE_URL is set
  migrate -path sql/migrations -database "$DATABASE_URL" up 1
  ```

  (Make sure it picks up the new migration number in sequence.)
* Or manually via psql:

  ```bash
  psql -U <db_user> -d <database_name> -c "ALTER TABLE users DROP COLUMN username;"
  ```

  Before doing this, **backup your database** as usual. After dropping the column, you may also want to remove any references in code configs (none expected, since we removed it in code).

**Updating Indexes & Constraints:** Dropping the column will automatically drop the associated index on it. No further index is needed since `email` was already indexed unique. It’s good to ensure that `email` has a NOT NULL constraint (it does in the GORM model) and unique index. You can verify that in the schema or explicitly add one if needed:

```sql
-- Ensure email is unique and not null (if not already)
ALTER TABLE users ALTER COLUMN email SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS users_email_uindex ON users(email);
```

In our case, this was likely done in a prior migration, but it’s worth double-checking.

**Environment/Config:** No config changes are needed for this migration. Just ensure any existing user records have an email (which they should) and that no logic still expects usernames. The default admin creation now supplies an email (“[admin@handreceipt.com](mailto:admin@handreceipt.com)”). You might want to communicate to any existing users that they will log in with their email going forward (if previously they had separate usernames).

**CLI Commands for Testing:**

* After deploying the changes, run the backend and perform a quick smoke test:

  ```bash
  # Start backend (assuming start-local.sh sets up env)
  backend/start-local.sh
  ```

  Then attempt to register a new user via API or through the frontend. The new user should be created without a username (check the DB: `SELECT username FROM users;` should show the column gone).
* Try logging in with the email and password – it should succeed (check that the session or JWT is issued).
* On iOS/Android, build and run the app. Verify you can log in with email. The UI should greet you or list your profile as “<Rank> <LastName>”. For example, if John Doe with rank CPT logs in, the app might show “Welcome, CPT Doe” instead of using a username.

By following all the above changes grouped by platform, the system will no longer use or store usernames. All login flows authenticate using email, and the applications consistently display users by rank and last name, improving clarity in a military context. These modifications keep the app functional and maintain security (unique emails and hashed passwords) while meeting the new requirements. Make sure to run the database migration and update all clients simultaneously to avoid any mismatches in expected fields. Enjoy the updated system!
