# DineEase

DineEase is a Flutter app with a dedicated **Web Admin Dashboard** for chefs/admins to manage orders and menu items. The admin experience is built on **Firebase Auth** and **Cloud Firestore**, and enforces role-based access for `admin` and `chef`.

This repository contains:
- Customer-facing UI (mobile/web)
- Admin/chef dashboard (web-only)

---

## Admin Dashboard Features

**Auth & Access**
- Email/password login with Firebase Auth
- Role check in Firestore: `users/{uid}.role`
- Only `admin` or `chef` can access the dashboard

**Orders**
- Live stream from `orders` collection
- Search by `orderNumber`, `user.name`, `user.phone`, `payment.method`
- Filter by stage: `placed`, `preparing`, `inKitchen`, `delivered`
- Summary header: totals + per-stage counts
- Update stage directly from the UI (writes to Firestore)

**Foods**
- Live stream from `foods` collection
- Search by title and category
- Create, edit, delete foods
- Validation for required and numeric fields
- Image URL preview
- Ingredients parsed from comma-separated text
- Food type chips (Popular Food / Delicious Foods)

**UI**
- Sidebar navigation with collapse/expand toggle
- Top search bar + logout
- Clean cards, badges, chips, and spacing
- App icon + name displayed at the top of the sidebar

---

## Tech Stack

- Flutter (Web)
- Firebase Auth (email/password)
- Cloud Firestore

---

## Firebase Setup

1. **Enable Email/Password Auth** in Firebase Console.
2. Create a `users/{uid}` document **for each admin/chef**:

```
users/{uid} {
  name: "Admin Name",
  phone: "+1-555-555-5555",
  role: "admin" | "chef",
  email: "admin@dineease.com"
}
```

3. Ensure Firestore security rules allow:
- Admin/chef read/write to `orders` and `foods`
- User document read by the user

---

---

## Firestore Schema

**Orders**
```
orders/{id} {
  orderNumber,
  user: { id, name, phone },
  items: [{ title, quantity, unitPrice, subtotal }],
  totals: { subtotal, deliveryFee, total },
  payment: { method, status },
  delivery: { type, address, tableNumber },
  stage,
  placedAt
}
```

**Foods**
```
foods/{id} {
  title, subtitle, category, description,
  imageUrl, time,
  price, rating, calories,
  ingredients: [string],
  foodType: [string]
}
```

---

## Running the Admin Dashboard (Web)

```
flutter pub get
flutter run -d chrome
```

The admin dashboard launches automatically on **web** (`kIsWeb`).

---

## Project Structure (Key)

- `lib/admin/`
  - `admin_app.dart` – Web-only admin app shell + theme
  - `admin_auth_gate.dart` – Auth + role gate
  - `admin_shell.dart` – Sidebar, top bar, layout
  - `orders_page.dart` – Orders management
  - `foods_page.dart` – Foods CRUD
  - `profile_page.dart` – Admin/chef profile
  - `login_page.dart` – Email/password login

---

## Notes

- The dashboard is designed for **chefs/admins only** and is intentionally not exposed to regular users.
- For mobile builds, the existing customer UI remains active.

---

## Troubleshooting

- **Access denied**: ensure `users/{uid}.role` is `admin` or `chef`.
- **Orders or foods not loading**: confirm Firestore security rules and collection names.
- **Image preview broken**: ensure `imageUrl` is a valid public URL.

---

## License

Private project. Not for public distribution.
