import { useState, useCallback } from "react";
import {
  ShoppingCart,
  PackageSearch,
  Calculator,
  Wallet,
  CheckCircle2,
  AlertTriangle,
  Trash2,
  Plus,
  Loader2,
} from "lucide-react";

// === Konfigurasi endpoint sesuai workflows/*.yaml ===
const PATH = {
  buka: "/webhook/kelompok3/umkm/pesanan/buka",
  validasiStok: "/webhook/kelompok3/umkm/produk/validasi-stok",
  kalkulasi: "/webhook/kelompok3/umkm/pesanan/kalkulasi-tagihan",
  konfirmasi: "/webhook/kelompok3/umkm/pesanan/konfirmasi-pembayaran",
  selesaikan: "/webhook/kelompok3/umkm/pesanan/selesaikan",
};

const STEP_LABEL = [
  "Buka Keranjang",
  "Validasi Stok",
  "Kalkulasi Tagihan",
  "Konfirmasi Bayar",
  "Selesaikan",
];

export default function PesananUMKM() {
  const [baseUrl, setBaseUrl] = useState("http://127.0.0.1:47800");
  const [kasirId, setKasirId] = useState("kasir-01");
  const [pelangganId, setPelangganId] = useState("1");
  const [tipePelanggan, setTipePelanggan] = useState("reguler");
  const [metodeBayar, setMetodeBayar] = useState("cash");
  const [metodeAmbil, setMetodeAmbil] = useState("dine_in");

  const [pesananId, setPesananId] = useState(null);
  const [step, setStep] = useState(0); // index aktif di STEP_LABEL
  const [loading, setLoading] = useState(false);
  const [log, setLog] = useState(null); // { ok, message, data }

  const [cart, setCart] = useState([
    { produk_id: "1", jumlah: "1", harga_satuan: "0", stokInfo: null },
  ]);
  const [tagihan, setTagihan] = useState(null); // hasil kalkulasi: { total_tagihan, diskon, ... }
  const [nominalDibayar, setNominalDibayar] = useState("");
  const [bayarResult, setBayarResult] = useState(null);

  // Helper fetch terpusat — semua endpoint pakai pola request/response yang sama.
  const callApi = useCallback(
    async (path, body) => {
      setLoading(true);
      setLog(null);
      try {
        const res = await fetch(`${baseUrl}${path}`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(body),
        });
        const data = await res.json();
        if (
          !res.ok ||
          data?.status === "rejected" ||
          data?.tersedia === false
        ) {
          setLog({
            ok: false,
            message: data?.pesan || data?.message || `HTTP ${res.status}`,
            data,
          });
          return { ok: false, data };
        }
        setLog({ ok: true, message: "Berhasil", data });
        return { ok: true, data };
      } catch (err) {
        setLog({ ok: false, message: err.message, data: null });
        return { ok: false, data: null };
      } finally {
        setLoading(false);
      }
    },
    [baseUrl],
  );

  // --- Workflow 1: Buka Keranjang ---
  const bukaKeranjang = async () => {
    const { ok, data } = await callApi(PATH.buka, {
      pelanggan_id: Number(pelangganId),
      kasir_id: kasirId,
    });
    if (ok) {
      setPesananId(data.pesanan_id);
      setStep(1);
    }
  };

  // --- Workflow 2: Validasi Stok (per baris keranjang) ---
  const validasiStok = async (idx) => {
    const item = cart[idx];
    const { ok, data } = await callApi(PATH.validasiStok, {
      produk_id: Number(item.produk_id),
      jumlah: Number(item.jumlah),
    });
    setCart((prev) =>
      prev.map((it, i) => (i === idx ? { ...it, stokInfo: data } : it)),
    );
    return ok;
  };

  const cartTotals = cart.reduce(
    (acc, it) => {
      const jumlah = Number(it.jumlah) || 0;
      const harga = Number(it.harga_satuan) || 0;
      return {
        subtotal: acc.subtotal + jumlah * harga,
        totalItem: acc.totalItem + jumlah,
      };
    },
    { subtotal: 0, totalItem: 0 },
  );

  const updateCartField = (idx, field, value) =>
    setCart((prev) =>
      prev.map((it, i) =>
        i === idx ? { ...it, [field]: value, stokInfo: null } : it,
      ),
    );
  const addCartRow = () =>
    setCart((prev) => [
      ...prev,
      { produk_id: "", jumlah: "1", harga_satuan: "0", stokInfo: null },
    ]);
  const removeCartRow = (idx) =>
    setCart((prev) => prev.filter((_, i) => i !== idx));

  // --- Workflow 3: Kalkulasi Tagihan (VRule fastpath) ---
  const kalkulasiTagihan = async () => {
    const { ok, data } = await callApi(PATH.kalkulasi, {
      pesanan_id: pesananId,
      kasir_id: kasirId,
      subtotal: cartTotals.subtotal,
      total_item: cartTotals.totalItem,
      tipe_pelanggan: tipePelanggan,
      metode_pembayaran: metodeBayar,
      metode_pengambilan: metodeAmbil,
    });
    if (ok) {
      setTagihan(data);
      setNominalDibayar(String(data.total_tagihan));
      setStep(3);
    }
  };

  // --- Workflow 4: Konfirmasi Pembayaran ---
  const konfirmasiPembayaran = async () => {
    const { ok, data } = await callApi(PATH.konfirmasi, {
      pesanan_id: pesananId,
      total_tagihan: tagihan?.total_tagihan,
      nominal_dibayar: Number(nominalDibayar),
    });
    setBayarResult(data);
    if (ok && data.status_pembayaran === "lunas") setStep(4);
  };

  // --- Workflow 5: Penyelesaian Pesanan ---
  const selesaikanPesanan = async () => {
    const { ok } = await callApi(PATH.selesaikan, { pesanan_id: pesananId });
    if (ok) setStep(5);
  };

  const resetAll = () => {
    setPesananId(null);
    setStep(0);
    setCart([
      { produk_id: "1", jumlah: "1", harga_satuan: "0", stokInfo: null },
    ]);
    setTagihan(null);
    setBayarResult(null);
    setNominalDibayar("");
    setLog(null);
  };

  const inputCls =
    "w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500";
  const btnCls =
    "inline-flex items-center justify-center gap-2 rounded-lg px-4 py-2 text-sm font-medium transition disabled:opacity-50 disabled:cursor-not-allowed";

  return (
    <div className="min-h-screen bg-slate-50 p-4 md:p-8">
      <div className="mx-auto max-w-3xl space-y-5">
        <header className="flex flex-wrap items-center justify-between gap-3">
          <h1 className="text-xl font-bold text-slate-800">
            Kasir UMKM — Pesanan
          </h1>
          {pesananId && (
            <span className="rounded-full bg-indigo-100 px-3 py-1 text-xs font-semibold text-indigo-700">
              Pesanan #{pesananId}
            </span>
          )}
        </header>

        {/* Stepper */}
        <div className="flex gap-1 overflow-x-auto pb-1">
          {STEP_LABEL.map((label, i) => (
            <div
              key={label}
              className={`flex-1 min-w-[90px] rounded-md px-2 py-1.5 text-center text-xs font-medium ${i === step ? "bg-indigo-600 text-white" : i < step ? "bg-emerald-100 text-emerald-700" : "bg-slate-200 text-slate-500"}`}
            >
              {i + 1}. {label}
            </div>
          ))}
        </div>

        {/* Config + Status bar */}
        <div className="grid grid-cols-2 gap-2 rounded-lg bg-white p-3 shadow-sm sm:grid-cols-3">
          <Field label="Base URL">
            <input
              className={inputCls}
              value={baseUrl}
              onChange={(e) => setBaseUrl(e.target.value)}
            />
          </Field>
          <Field label="Kasir ID">
            <input
              className={inputCls}
              value={kasirId}
              onChange={(e) => setKasirId(e.target.value)}
              disabled={step > 0}
            />
          </Field>
          <Field label="Pelanggan ID">
            <input
              className={inputCls}
              value={pelangganId}
              onChange={(e) => setPelangganId(e.target.value)}
              disabled={step > 0}
            />
          </Field>
        </div>

        {log && (
          <div
            className={`flex items-start gap-2 rounded-lg p-3 text-sm ${log.ok ? "bg-emerald-50 text-emerald-700" : "bg-rose-50 text-rose-700"}`}
          >
            {log.ok ? (
              <CheckCircle2 size={18} className="mt-0.5 shrink-0" />
            ) : (
              <AlertTriangle size={18} className="mt-0.5 shrink-0" />
            )}
            <div>
              <p className="font-medium">{log.message}</p>
              {log.data && (
                <pre className="mt-1 max-h-32 overflow-auto text-xs opacity-80">
                  {JSON.stringify(log.data, null, 2)}
                </pre>
              )}
            </div>
          </div>
        )}

        {/* STEP 0: Buka Keranjang */}
        {step === 0 && (
          <Card
            icon={<ShoppingCart size={18} />}
            title="Buka Keranjang Pesanan"
          >
            <button
              className={`${btnCls} bg-indigo-600 text-white hover:bg-indigo-700`}
              disabled={loading}
              onClick={bukaKeranjang}
            >
              {loading ? (
                <Loader2 size={16} className="animate-spin" />
              ) : (
                <ShoppingCart size={16} />
              )}{" "}
              Mulai Pesanan
            </button>
          </Card>
        )}

        {/* STEP 1: Validasi Stok + susun keranjang */}
        {step === 1 && (
          <Card
            icon={<PackageSearch size={18} />}
            title="Item Pesanan & Validasi Stok"
          >
            <div className="space-y-2">
              {cart.map((it, idx) => (
                <div
                  key={idx}
                  className="grid grid-cols-12 items-center gap-2 rounded-lg border border-slate-200 p-2"
                >
                  <input
                    className={`${inputCls} col-span-2`}
                    placeholder="ID Produk"
                    value={it.produk_id}
                    onChange={(e) =>
                      updateCartField(idx, "produk_id", e.target.value)
                    }
                  />
                  <input
                    className={`${inputCls} col-span-2`}
                    placeholder="Jumlah"
                    type="number"
                    value={it.jumlah}
                    onChange={(e) =>
                      updateCartField(idx, "jumlah", e.target.value)
                    }
                  />
                  <input
                    className={`${inputCls} col-span-3`}
                    placeholder="Harga satuan"
                    type="number"
                    value={it.harga_satuan}
                    onChange={(e) =>
                      updateCartField(idx, "harga_satuan", e.target.value)
                    }
                  />
                  <button
                    className={`${btnCls} col-span-3 bg-slate-100 text-slate-700 hover:bg-slate-200`}
                    disabled={loading}
                    onClick={() => validasiStok(idx)}
                  >
                    Cek Stok
                  </button>
                  <span
                    className={`col-span-1 text-xs font-medium ${it.stokInfo?.tersedia ? "text-emerald-600" : it.stokInfo ? "text-rose-600" : "text-slate-400"}`}
                  >
                    {it.stokInfo ? (it.stokInfo.tersedia ? "OK" : "✕") : "—"}
                  </span>
                  <button
                    className="col-span-1 text-slate-400 hover:text-rose-600"
                    onClick={() => removeCartRow(idx)}
                  >
                    <Trash2 size={16} />
                  </button>
                </div>
              ))}
              <button
                className={`${btnCls} text-indigo-600`}
                onClick={addCartRow}
              >
                <Plus size={14} /> Tambah item
              </button>
            </div>

            <div className="mt-3 grid grid-cols-3 gap-2 text-sm">
              <Field label="Tipe Pelanggan">
                <select
                  className={inputCls}
                  value={tipePelanggan}
                  onChange={(e) => setTipePelanggan(e.target.value)}
                >
                  <option value="reguler">Reguler</option>
                  <option value="member">Member</option>
                </select>
              </Field>
              <Field label="Metode Bayar">
                <select
                  className={inputCls}
                  value={metodeBayar}
                  onChange={(e) => setMetodeBayar(e.target.value)}
                >
                  <option value="cash">Cash</option>
                  <option value="qris">QRIS</option>
                  <option value="transfer">Transfer</option>
                </select>
              </Field>
              <Field label="Metode Ambil">
                <select
                  className={inputCls}
                  value={metodeAmbil}
                  onChange={(e) => setMetodeAmbil(e.target.value)}
                >
                  <option value="dine_in">Dine In</option>
                  <option value="take_away">Take Away</option>
                  <option value="delivery">Delivery</option>
                </select>
              </Field>
            </div>

            <div className="mt-3 flex items-center justify-between border-t pt-3 text-sm">
              <span className="text-slate-500">
                Subtotal:{" "}
                <b>Rp {cartTotals.subtotal.toLocaleString("id-ID")}</b> ·{" "}
                {cartTotals.totalItem} item
              </span>
              <button
                className={`${btnCls} bg-indigo-600 text-white hover:bg-indigo-700`}
                disabled={loading || cartTotals.totalItem === 0}
                onClick={() => setStep(2)}
              >
                Lanjut Kalkulasi
              </button>
            </div>
          </Card>
        )}

        {/* STEP 2: Kalkulasi Tagihan */}
        {step === 2 && (
          <Card
            icon={<Calculator size={18} />}
            title="Kalkulasi Total Tagihan (VRule Engine)"
          >
            <p className="text-sm text-slate-500">
              Subtotal Rp {cartTotals.subtotal.toLocaleString("id-ID")} ·{" "}
              {cartTotals.totalItem} item · {tipePelanggan} · {metodeBayar} ·{" "}
              {metodeAmbil}
            </p>
            <button
              className={`${btnCls} mt-3 bg-indigo-600 text-white hover:bg-indigo-700`}
              disabled={loading}
              onClick={kalkulasiTagihan}
            >
              {loading ? (
                <Loader2 size={16} className="animate-spin" />
              ) : (
                <Calculator size={16} />
              )}{" "}
              Hitung Tagihan
            </button>
          </Card>
        )}

        {/* STEP 3: Konfirmasi Pembayaran */}
        {step === 3 && tagihan && (
          <Card icon={<Wallet size={18} />} title="Konfirmasi Pembayaran">
            <dl className="grid grid-cols-2 gap-1 text-sm text-slate-600">
              <dt>Subtotal</dt>
              <dd className="text-right">
                Rp {tagihan.subtotal?.toLocaleString("id-ID")}
              </dd>
              <dt>Diskon</dt>
              <dd className="text-right">
                - Rp {tagihan.diskon?.toLocaleString("id-ID")}
              </dd>
              <dt>Biaya Admin</dt>
              <dd className="text-right">
                Rp {tagihan.biaya_admin?.toLocaleString("id-ID")}
              </dd>
              <dt>Biaya Kirim</dt>
              <dd className="text-right">
                Rp {tagihan.biaya_pengiriman?.toLocaleString("id-ID")}
              </dd>
              <dt className="font-bold">Total Tagihan</dt>
              <dd className="text-right font-bold">
                Rp {tagihan.total_tagihan?.toLocaleString("id-ID")}
              </dd>
            </dl>
            <Field label="Nominal Dibayar">
              <input
                className={inputCls}
                type="number"
                value={nominalDibayar}
                onChange={(e) => setNominalDibayar(e.target.value)}
              />
            </Field>
            <button
              className={`${btnCls} mt-3 bg-indigo-600 text-white hover:bg-indigo-700`}
              disabled={loading}
              onClick={konfirmasiPembayaran}
            >
              {loading ? (
                <Loader2 size={16} className="animate-spin" />
              ) : (
                <Wallet size={16} />
              )}{" "}
              Konfirmasi Bayar
            </button>
            {bayarResult &&
              bayarResult.status_pembayaran === "kurang_bayar" && (
                <p className="mt-2 text-sm text-rose-600">
                  Kurang bayar: Rp{" "}
                  {bayarResult.kekurangan?.toLocaleString("id-ID")}
                </p>
              )}
          </Card>
        )}

        {/* STEP 4: Selesaikan Pesanan */}
        {step === 4 && (
          <Card icon={<CheckCircle2 size={18} />} title="Selesaikan Pesanan">
            <p className="text-sm text-emerald-600 mb-3">
              Pembayaran lunas. Kembalian: Rp{" "}
              {bayarResult?.kembalian?.toLocaleString("id-ID")}
            </p>
            <button
              className={`${btnCls} bg-emerald-600 text-white hover:bg-emerald-700`}
              disabled={loading}
              onClick={selesaikanPesanan}
            >
              {loading ? (
                <Loader2 size={16} className="animate-spin" />
              ) : (
                <CheckCircle2 size={16} />
              )}{" "}
              Tutup Transaksi & Update Stok
            </button>
          </Card>
        )}

        {/* STEP 5: Selesai */}
        {step === 5 && (
          <Card icon={<CheckCircle2 size={18} />} title="Pesanan Selesai">
            <p className="text-sm text-slate-600">
              Pesanan #{pesananId} berstatus <b>selesai</b>. Stok produk telah
              diperbarui.
            </p>
            <button
              className={`${btnCls} mt-3 bg-slate-800 text-white hover:bg-slate-900`}
              onClick={resetAll}
            >
              Pesanan Baru
            </button>
          </Card>
        )}
      </div>
    </div>
  );
}

function Card({ icon, title, children }) {
  return (
    <section className="rounded-xl bg-white p-4 shadow-sm">
      <h2 className="mb-3 flex items-center gap-2 text-sm font-semibold text-slate-700">
        {icon}
        {title}
      </h2>
      {children}
    </section>
  );
}

function Field({ label, children }) {
  return (
    <label className="block text-xs font-medium text-slate-500">
      {label}
      <div className="mt-1">{children}</div>
    </label>
  );
}
