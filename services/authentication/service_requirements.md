# Access Control & Authentication Requirements (Updated Specification)

## 1. Purpose
Implement a lightweight, scalable authentication and authorization system using a dedicated microservice, suitable for low-end hardware (e.g., Raspberry Pi).

## 2. Access Control Rules
1. **Write APIs (create / update / delete)**  
   - Must require authentication.

2. **Read APIs**  
   - **By default** read APIs are open.  
   - There must be a configuration option (settable by an admin) to **bring read APIs under authentication** if needed.

3. **Demo Server Mode**  
   - At server startup, authentication can be **globally disabled**.  
   - In demo mode, **all APIs** (read + write) are accessible without authentication.

## 3. Authentication & Authorization Microservice: `user_auth`

### 3.1 Responsibilities
- Manage user accounts (create, update, delete users).  
- Manage user permissions.  
- Authenticate users.  
- Issue JWT tokens (ES256).  
- Expose a minimal, fast API suitable for low-end devices.

## 4. Permissions Model

### 4.1 Permissions
Define permissions as plain strings. Examples:
- `media_store_write`
- `media_store_read`

The system must be designed to **easily add new permissions in the future** without restructuring the service.

### 4.2 Authorization Rules
- Each user can have a set of permissions.
- `media_store` checks:
  - If authentication is **enabled** and the API is protected:
    - The JWT must be valid.
    - The required permission must be present in the token’s claims.
  - If authentication is **disabled**:
    - All operations are allowed.

### 4.3 Admin User
- There is **one single admin user** who manages:
  - Creating and updating users  
  - Assigning permissions  
  - Enabling/disabling authentication for read APIs  
- Admin operations must be performed **only through designated admin APIs**, protected by admin authentication.

## 5. Integration with `media_store`
- `media_store` receives a JWT and validates it with the `user_auth` public key.
- It does **not** store or manage user details.
- It only checks:
  1. **Is the token valid?**
  2. **Does the user have the required permission for this API?**
- Behavior:
  - **Write APIs → require `media_store_write`**  
  - **Read APIs → require `media_store_read` only if admin has enabled read-access-control**

## 6. Testing Requirements

### 6.1 `user_auth` Tests
- User creation, update, deletion  
- Permission assignment  
- Authentication flow  
- JWT generation and signature validation  
- Admin APIs (correctly protected)

### 6.2 `media_store` Tests
Test across three modes:

#### A. Normal Mode (Auth Enabled + Default Read Open)
- Write API + valid token + permission → success  
- Write API + no/invalid token → fail  
- Read API → allowed  

#### B. Read Auth Enabled (Admin toggled)
- Read API + valid token + `media_store_read` → success  
- Read API + invalid or missing permission → fail  

#### C. Demo Mode (Auth Disabled)
- All APIs → allowed without token  
