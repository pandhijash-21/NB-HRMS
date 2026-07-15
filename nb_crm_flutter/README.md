# NB Developer CRM+HRMS+ERP — Flutter client

REST-only Flutter frontend (sibling to `frontend/` and `backend/`).
Talks directly to Express at `API_BASE_URL` (default: `http://127.0.0.1:4000/api`).

## Run

```bash
# From repo root — default API URL matches frontend/.env NEXT_PUBLIC_API_URL
cd nb_crm_flutter

# Chrome (recommended on this machine if Windows Developer Mode is off)
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:4000/api

# Windows desktop requires Developer Mode (symlink support for plugins)
flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:4000/api
```

### Auth flow (login ↔ change-password ↔ home)

| Account | Identifier | Notes |
|---|---|---|
| Admin (first login) | `1` / `01011998` | Forced `/change-password` until password rotated |
| Employee 4 (API verified) | `4` / `NbDev4242` | Password already changed in local E2E verify |

After change-password, session is cleared and login shows "Password changed. Please log in again."

## Structure

```
lib/
  core/           network, storage, router, theme
  features/auth/  login pilot (data / domain / presentation)
  features/home/  post-login stubs
  main.dart
```

## Notes

- No GraphQL / Hasura client — Express REST only.
- Auth token in `flutter_secure_storage`; session in Riverpod `AuthNotifier`.
- Router guard: unauthenticated users can only open `/login`.
