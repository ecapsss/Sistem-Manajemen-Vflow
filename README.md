# Sistem Manajemen Pesanan UMKM Berbasis VFlow

Repo ini berisi workflow Kelompok 3 untuk aplikasi UMKM di server VFlow
bersama:

```text
https://sqavflow.vastar.id
```

Layanan bersama sudah disiapkan oleh pembimbing. Anak magang cukup fokus pada
workflow, database lokal, provision ke VFlow, dan testing.

## Namespace Kelompok 3

Karena server dipakai beberapa kelompok, semua resource Kelompok 3 memakai
namespace sendiri:

| Resource | Nilai |
|---|---|
| Webhook prefix | `/webhook/kelompok3/...` |
| Workflow id | `kelompok3-...` |
| Rule set id | `kelompok3_aturan_harga_umkm_v1` |
| Connection pack id | `kelompok3-umkm` |
| DB connector ref | `pack://kelompok3-umkm/primary` |
| DB tunnel runtime | `db-tunnel.vastar.id:15433` |

Jangan mengganti prefix/path ke kelompok lain.

## Struktur Repo

```text
workflows/
  01-buka-keranjang.yaml
  02-validasi-stok.yaml
  03-kalkulasi-tagihan.yaml
  04-konfirmasi-pembayaran.yaml
  05-penyelesaian-pesanan.yaml
  06-audit-log.yaml
rules/
  aturan_harga_umkm_v1.vdicl
schemas/
  harga_fact_v1.yaml
db/
  schema.sql
frontend/
  src/
    App.jsx
    PesananUMKM.jsx
  vite.config.js
  package.json
pack.yaml
scripts/
  vflow-admin.sh
  make-pack-install.js
test/
  smoke-test.sh
```

## Prasyarat Anak Magang

Install di laptop/mesin kerja:

```text
curl
jq
node
psql
rathole
```

Minta ke pembimbing:

```text
VFLOW_ADMIN_KEY
VFLOW_PACK_SECRET_KEY_B64
LOGSTREAM_TOKEN
kel3-client.toml
```

`kel3-client.toml` adalah config rathole client untuk menghubungkan PostgreSQL
lokal Kelompok 3 ke server VFlow. File ini cukup dijalankan, tidak perlu
diubah.

## Alur Kerja Harian

### 1. Siapkan Database Lokal

Pastikan PostgreSQL lokal berjalan di laptop/mesin Kelompok 3.

Contoh DSN lokal:

```bash
export LOCAL_DATABASE_URL="postgresql://user:pass@127.0.0.1:5432/db_kelompok3"
psql "$LOCAL_DATABASE_URL" -f db/schema.sql
```

`LOCAL_DATABASE_URL` hanya untuk migration dan verifikasi lokal.

### 2. Jalankan Tunnel DB Kelompok 3

Di terminal terpisah:

```bash
rathole kel3-client.toml
```

Selama proses ini hidup, server VFlow dapat mengakses DB Kelompok 3 lewat:

```text
db-tunnel.vastar.id:15433
```

Jangan memakai `localhost` atau `127.0.0.1` untuk DSN runtime VFlow, karena dari
sisi VFlow alamat itu berarti node VFlow sendiri.

### 3. Set Environment VFlow

```bash
export VFLOW_BASE_URL="https://sqavflow.vastar.id"
export VFLOW_TENANT="_default"
export VFLOW_ADMIN_KEY="<dari-pembimbing>"
export VFLOW_PACK_SECRET_KEY_B64="<dari-pembimbing>"
```

DSN runtime untuk connection pack harus memakai tunnel:

```bash
export KELOMPOK3_DATABASE_URL="postgresql://user:pass@db-tunnel.vastar.id:15433/db_kelompok3"
```

### 4. Install Connection Pack

Generate payload encrypted:

```bash
node scripts/make-pack-install.js > pack-install.local.json
```

Install ke VFlow:

```bash
./scripts/vflow-admin.sh packs install pack-install.local.json
```

Expected response memuat:

```json
{
  "installed": "kelompok3-umkm",
  "connections": [
    { "name": "primary", "kind": "postgres" }
  ]
}
```

### 5. Compile Rule Pack

```bash
./scripts/vflow-admin.sh rules compile \
  rules/aturan_harga_umkm_v1.vdicl \
  schemas/harga_fact_v1.yaml \
  kelompok3_aturan_harga_umkm_v1
```

### 6. Provision Workflow

```bash
for f in workflows/*.yaml; do
  echo "== provisioning $f =="
  ./scripts/vflow-admin.sh workflows provision "$f"
done
```

### 7. Smoke Test

```bash
bash test/smoke-test.sh
```

Hasil sehat:

```text
Ringkasan: 20 PASS, 0 FAIL
```

## Public Webhook

| Workflow | Endpoint |
|---|---|
| Buka Keranjang | `POST /webhook/kelompok3/umkm/pesanan/buka` |
| Validasi Stok | `POST /webhook/kelompok3/umkm/produk/validasi-stok` |
| Kalkulasi Tagihan | `POST /webhook/kelompok3/umkm/pesanan/kalkulasi-tagihan` |
| Konfirmasi Pembayaran | `POST /webhook/kelompok3/umkm/pesanan/konfirmasi-pembayaran` |
| Penyelesaian Pesanan | `POST /webhook/kelompok3/umkm/pesanan/selesaikan` |
| Audit Log | `POST /webhook/kelompok3/umkm/internal/audit-log` |

Contoh:

```bash
curl -sS -X POST "$VFLOW_BASE_URL/webhook/kelompok3/umkm/pesanan/buka" \
  -H "content-type: application/json" \
  -d '{"pelanggan_id":1,"kasir_id":"kasir01"}'
```

## Frontend

Folder `frontend/` berisi UI Kasir (React + Vite + Tailwind) yang
mengonsumsi 5 endpoint webhook publik di atas secara berurutan: buka
keranjang → validasi stok → kalkulasi tagihan → konfirmasi pembayaran →
selesaikan pesanan.

### Menjalankan

```bash
cd frontend
npm install
npm run dev
```

Buka `http://localhost:5173`.

### Konfigurasi

Di field **Base URL** pada UI, isi dengan alamat server VFlow bersama:

```text
https://sqavflow.vastar.id
```

Pastikan tunnel DB (`rathole kel3-client.toml`) dan provisioning workflow
(lihat [Alur Kerja Harian](#alur-kerja-harian) di atas) sudah berjalan
sebelum melakukan testing dari UI ini, karena frontend memanggil langsung
endpoint publik di server bersama.

### Komponen Utama

| File | Fungsi |
|---|---|
| `src/PesananUMKM.jsx` | Komponen kasir end-to-end, state machine 5 step sesuai urutan workflow |
| `src/App.jsx` | Entry point, merender `PesananUMKM` |

## Logstream

Untuk melihat log VFlow yang relevan:

```bash
export LOGSTREAM_TOKEN="<dari-pembimbing>"

curl -N \
  -H "Authorization: Bearer $LOGSTREAM_TOKEN" \
  "https://sqavflow.vastar.id/logs/vflow-server?tail=100&follow=true&timestamps=true"
```

Logstream hanya memberi akses baca log runtime yang relevan untuk debugging.

## Batasan Penting

- Jangan memakai `localhost` atau `127.0.0.1` di `KELOMPOK3_DATABASE_URL`.
- Jangan mengubah namespace `/webhook/kelompok3/...`.
- Jangan memakai bare `connector_ref: postgres`; gunakan
  `pack://kelompok3-umkm/primary`.
- Jangan mengunggah secret ke chat publik. Jika token bocor, minta pembimbing
  rotasi token.
