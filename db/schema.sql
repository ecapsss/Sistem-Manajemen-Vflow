-- =============================================================
-- Skema PostgreSQL — Sistem Manajemen Pesanan UMKM Berbasis VFlow
-- Sesuai Bab 9 (Database) pada dokumen spesifikasi.
-- =============================================================

CREATE TABLE IF NOT EXISTS produk (
    id          SERIAL PRIMARY KEY,
    nama        VARCHAR(150) NOT NULL,
    harga       NUMERIC(14,2) NOT NULL CHECK (harga >= 0),
    stok        INTEGER NOT NULL CHECK (stok >= 0),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pelanggan (
    id              SERIAL PRIMARY KEY,
    nama            VARCHAR(150) NOT NULL,
    tipe_pelanggan  VARCHAR(20) NOT NULL DEFAULT 'reguler'
                    CHECK (tipe_pelanggan IN ('reguler', 'member')),
    kontak          VARCHAR(100),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pesanan (
    id              SERIAL PRIMARY KEY,
    pelanggan_id    INTEGER REFERENCES pelanggan(id),
    kasir_id        VARCHAR(50) NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'draft'
                    CHECK (status IN ('draft', 'lunas', 'selesai', 'batal')),
    subtotal        NUMERIC(14,2) NOT NULL DEFAULT 0,
    diskon          NUMERIC(14,2) NOT NULL DEFAULT 0,
    biaya_admin     NUMERIC(14,2) NOT NULL DEFAULT 0,
    biaya_pengiriman NUMERIC(14,2) NOT NULL DEFAULT 0,
    total_tagihan   NUMERIC(14,2) NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS detail_pesanan (
    id          SERIAL PRIMARY KEY,
    pesanan_id  INTEGER NOT NULL REFERENCES pesanan(id) ON DELETE CASCADE,
    produk_id   INTEGER NOT NULL REFERENCES produk(id),
    jumlah      INTEGER NOT NULL CHECK (jumlah > 0),
    harga_satuan NUMERIC(14,2) NOT NULL
);

CREATE TABLE IF NOT EXISTS audit_log (
    id              BIGSERIAL PRIMARY KEY,
    pesanan_id      VARCHAR(50) NOT NULL,
    aktor_id        VARCHAR(50) NOT NULL,
    aktivitas_tipe  VARCHAR(50) NOT NULL,
    payload_log     JSONB NOT NULL DEFAULT '{}'::jsonb,
    waktu_kejadian  TIMESTAMPTZ NOT NULL DEFAULT now(),
    recorded_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pesanan_status ON pesanan(status);
CREATE INDEX IF NOT EXISTS idx_detail_pesanan_pesanan_id ON detail_pesanan(pesanan_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_pesanan_id ON audit_log(pesanan_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_waktu ON audit_log(waktu_kejadian);

-- Contoh data awal untuk pengujian cepat.
INSERT INTO produk (nama, harga, stok) VALUES
    ('Kopi Susu Gula Aren', 18000, 50),
    ('Roti Bakar Coklat', 15000, 30),
    ('Es Teh Manis', 5000, 100)
ON CONFLICT DO NOTHING;

INSERT INTO pelanggan (nama, tipe_pelanggan, kontak) VALUES
    ('Pelanggan Umum', 'reguler', '081200000000'),
    ('Budi (Member)', 'member', '081211112222')
ON CONFLICT DO NOTHING;
