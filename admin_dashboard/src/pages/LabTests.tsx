import { useState, useEffect } from 'react';
import { Plus, Pencil, Trash2, X, Search } from 'lucide-react';
import { API_BASE } from '../config';

interface LabTest {
  id: string;
  name: string;
  category: string;
  price: number;
  turnaround: string;
  sample_type: string;
  fasting_required: boolean;
  description: string;
  is_active: boolean;
}

const CATEGORIES = ['Blood', 'Urine', 'Imaging', 'STD', 'Other'];

const emptyTest: Omit<LabTest, 'id'> = {
  name: '', category: 'Blood', price: 0, turnaround: '', sample_type: '',
  fasting_required: false, description: '', is_active: true,
};

export default function LabTests() {
  const [tests, setTests] = useState<LabTest[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing] = useState<LabTest | null>(null);
  const [form, setForm] = useState(emptyTest);
  const [saving, setSaving] = useState(false);

  const token = localStorage.getItem('clinix_admin_token');
  const headers = { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' };

  const fetchTests = async () => {
    setLoading(true);
    try {
      const res = await fetch(`${API_BASE}/lab-tests/admin/`, { headers });
      const data = await res.json();
      setTests(Array.isArray(data) ? data : data.results || []);
    } catch (e) { console.error(e); }
    setLoading(false);
  };

  useEffect(() => { fetchTests(); }, []);

  const openCreate = () => { setEditing(null); setForm(emptyTest); setShowModal(true); };
  const openEdit = (t: LabTest) => { setEditing(t); setForm({ ...t }); setShowModal(true); };

  const handleSave = async () => {
    setSaving(true);
    try {
      const url = editing
        ? `${API_BASE}/lab-tests/admin/${editing.id}/`
        : `${API_BASE}/lab-tests/admin/`;
      await fetch(url, {
        method: editing ? 'PUT' : 'POST',
        headers,
        body: JSON.stringify(form),
      });
      setShowModal(false);
      fetchTests();
    } catch (e) { console.error(e); }
    setSaving(false);
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Delete this lab test?')) return;
    await fetch(`${API_BASE}/lab-tests/admin/${id}/`, { method: 'DELETE', headers });
    fetchTests();
  };

  const filtered = tests.filter(t =>
    t.name.toLowerCase().includes(search.toLowerCase()) ||
    t.category.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Lab Tests</h1>
          <p className="text-sm text-slate-500">{tests.length} tests configured</p>
        </div>
        <button onClick={openCreate} className="flex items-center gap-2 bg-slate-900 text-white px-4 py-2.5 rounded-xl text-sm font-semibold hover:bg-slate-800 transition">
          <Plus size={16} /> Add Test
        </button>
      </div>

      <div className="relative mb-4">
        <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
        <input
          value={search} onChange={e => setSearch(e.target.value)}
          placeholder="Search tests..."
          className="w-full pl-10 pr-4 py-2.5 rounded-xl border border-slate-200 text-sm focus:outline-none focus:ring-2 focus:ring-slate-900/20"
        />
      </div>

      {loading ? (
        <div className="text-center py-12 text-slate-400">Loading...</div>
      ) : (
        <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-slate-50 border-b border-slate-200">
                <th className="text-left px-4 py-3 font-semibold text-slate-600">Name</th>
                <th className="text-left px-4 py-3 font-semibold text-slate-600">Category</th>
                <th className="text-left px-4 py-3 font-semibold text-slate-600">Price</th>
                <th className="text-left px-4 py-3 font-semibold text-slate-600">Turnaround</th>
                <th className="text-left px-4 py-3 font-semibold text-slate-600">Fasting</th>
                <th className="text-left px-4 py-3 font-semibold text-slate-600">Active</th>
                <th className="text-right px-4 py-3 font-semibold text-slate-600">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map(t => (
                <tr key={t.id} className="border-b border-slate-100 hover:bg-slate-50 transition">
                  <td className="px-4 py-3 font-medium text-slate-900">{t.name}</td>
                  <td className="px-4 py-3"><span className="px-2 py-1 bg-slate-100 rounded-lg text-xs font-medium">{t.category}</span></td>
                  <td className="px-4 py-3 font-semibold">{t.price.toLocaleString()} XAF</td>
                  <td className="px-4 py-3 text-slate-500">{t.turnaround}</td>
                  <td className="px-4 py-3">{t.fasting_required ? <span className="text-orange-500 font-medium">Yes</span> : <span className="text-slate-400">No</span>}</td>
                  <td className="px-4 py-3">{t.is_active ? <span className="w-2 h-2 bg-green-500 rounded-full inline-block"></span> : <span className="w-2 h-2 bg-red-400 rounded-full inline-block"></span>}</td>
                  <td className="px-4 py-3 text-right">
                    <button onClick={() => openEdit(t)} className="p-1.5 hover:bg-slate-100 rounded-lg transition mr-1"><Pencil size={14} className="text-slate-500" /></button>
                    <button onClick={() => handleDelete(t.id)} className="p-1.5 hover:bg-red-50 rounded-lg transition"><Trash2 size={14} className="text-red-400" /></button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {filtered.length === 0 && <div className="text-center py-8 text-slate-400">No tests found</div>}
        </div>
      )}

      {/* Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between px-6 py-4 border-b border-slate-200">
              <h2 className="font-bold text-lg text-slate-900">{editing ? 'Edit Test' : 'Add New Test'}</h2>
              <button onClick={() => setShowModal(false)}><X size={20} className="text-slate-400" /></button>
            </div>
            <div className="px-6 py-4 space-y-4">
              <div>
                <label className="text-xs font-semibold text-slate-600 mb-1 block">Test Name</label>
                <input value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} className="w-full px-3 py-2.5 rounded-xl border border-slate-200 text-sm focus:outline-none focus:ring-2 focus:ring-slate-900/20" />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-xs font-semibold text-slate-600 mb-1 block">Category</label>
                  <select value={form.category} onChange={e => setForm({ ...form, category: e.target.value })} className="w-full px-3 py-2.5 rounded-xl border border-slate-200 text-sm focus:outline-none">
                    {CATEGORIES.map(c => <option key={c} value={c}>{c}</option>)}
                  </select>
                </div>
                <div>
                  <label className="text-xs font-semibold text-slate-600 mb-1 block">Price (XAF)</label>
                  <input type="number" value={form.price} onChange={e => setForm({ ...form, price: parseInt(e.target.value) || 0 })} className="w-full px-3 py-2.5 rounded-xl border border-slate-200 text-sm focus:outline-none" />
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-xs font-semibold text-slate-600 mb-1 block">Turnaround Time</label>
                  <input value={form.turnaround} onChange={e => setForm({ ...form, turnaround: e.target.value })} placeholder="e.g. 24h" className="w-full px-3 py-2.5 rounded-xl border border-slate-200 text-sm focus:outline-none" />
                </div>
                <div>
                  <label className="text-xs font-semibold text-slate-600 mb-1 block">Sample Type</label>
                  <input value={form.sample_type} onChange={e => setForm({ ...form, sample_type: e.target.value })} placeholder="e.g. Blood (venous)" className="w-full px-3 py-2.5 rounded-xl border border-slate-200 text-sm focus:outline-none" />
                </div>
              </div>
              <div>
                <label className="text-xs font-semibold text-slate-600 mb-1 block">Description</label>
                <textarea value={form.description} onChange={e => setForm({ ...form, description: e.target.value })} rows={3} className="w-full px-3 py-2.5 rounded-xl border border-slate-200 text-sm focus:outline-none resize-none" />
              </div>
              <div className="flex items-center gap-6">
                <label className="flex items-center gap-2 text-sm">
                  <input type="checkbox" checked={form.fasting_required} onChange={e => setForm({ ...form, fasting_required: e.target.checked })} className="rounded" />
                  Fasting Required
                </label>
                <label className="flex items-center gap-2 text-sm">
                  <input type="checkbox" checked={form.is_active} onChange={e => setForm({ ...form, is_active: e.target.checked })} className="rounded" />
                  Active
                </label>
              </div>
            </div>
            <div className="px-6 py-4 border-t border-slate-200 flex gap-3">
              <button onClick={() => setShowModal(false)} className="flex-1 py-2.5 rounded-xl border border-slate-200 text-sm font-semibold text-slate-600 hover:bg-slate-50 transition">Cancel</button>
              <button onClick={handleSave} disabled={saving || !form.name} className="flex-1 py-2.5 rounded-xl bg-slate-900 text-white text-sm font-semibold hover:bg-slate-800 transition disabled:opacity-50">{saving ? 'Saving...' : 'Save'}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
