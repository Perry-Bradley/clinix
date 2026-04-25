import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Plus, Trash2, Stethoscope, HeartPulse, X } from 'lucide-react';
import { API_BASE } from '../config';

interface Specialty {
  specialty_id: string;
  name: string;
  role: 'specialist' | 'nurse';
  description: string | null;
  is_active: boolean;
  created_at: string;
}

const authHeader = () => ({
  Authorization: `Bearer ${localStorage.getItem('clinix_admin_token')}`,
});

const fetchSpecialties = async (): Promise<Specialty[]> => {
  const res = await fetch(`${API_BASE}/admin/specialties/`, {
    headers: authHeader(),
  });
  if (!res.ok) throw new Error('Failed to load specialties');
  return res.json();
};

const Specialties = () => {
  const qc = useQueryClient();
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [filter, setFilter] = useState<'all' | 'specialist' | 'nurse'>('all');
  const [form, setForm] = useState({
    name: '',
    role: 'specialist' as 'specialist' | 'nurse',
    description: '',
  });

  const { data: specialties = [], isLoading } = useQuery<Specialty[]>({
    queryKey: ['specialties'],
    queryFn: fetchSpecialties,
  });

  const createMutation = useMutation({
    mutationFn: async (payload: typeof form) => {
      const res = await fetch(`${API_BASE}/admin/specialties/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...authHeader() },
        body: JSON.stringify(payload),
      });
      if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        throw new Error(data.name?.[0] || data.detail || 'Could not create specialty');
      }
      return res.json();
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['specialties'] });
      setIsModalOpen(false);
      setForm({ name: '', role: 'specialist', description: '' });
    },
  });

  const deleteMutation = useMutation({
    mutationFn: async (id: string) => {
      const res = await fetch(`${API_BASE}/admin/specialties/${id}/`, {
        method: 'DELETE',
        headers: authHeader(),
      });
      if (!res.ok) throw new Error('Could not delete');
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['specialties'] }),
  });

  const toggleActive = useMutation({
    mutationFn: async (item: Specialty) => {
      const res = await fetch(`${API_BASE}/admin/specialties/${item.specialty_id}/`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', ...authHeader() },
        body: JSON.stringify({ is_active: !item.is_active }),
      });
      if (!res.ok) throw new Error('Could not update');
      return res.json();
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['specialties'] }),
  });

  const filtered = specialties.filter((s) => filter === 'all' || s.role === filter);

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <div>
          <h2 className="text-2xl font-bold text-dark-900">Specialties</h2>
          <p className="text-gray-500 text-sm mt-1">
            Configure the specialty options shown to providers when they sign up.
          </p>
        </div>
        <button
          onClick={() => setIsModalOpen(true)}
          className="flex items-center space-x-2 px-4 py-2.5 rounded-xl text-white font-semibold text-sm shadow-md transition-all"
          style={{ background: 'linear-gradient(135deg, #1B4080, #0EA5E9)' }}
        >
          <Plus size={16} />
          <span>Add Specialty</span>
        </button>
      </div>

      {/* Filter chips */}
      <div className="flex items-center space-x-2 mb-6">
        {(['all', 'specialist', 'nurse'] as const).map((f) => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className={`px-4 py-2 rounded-full text-xs font-bold transition ${
              filter === f
                ? 'bg-dark-900 text-white'
                : 'bg-white text-gray-600 border border-gray-200 hover:border-dark-900'
            }`}
          >
            {f === 'all' ? 'All' : f === 'specialist' ? 'Specialists' : 'Nurses'}
            <span className="ml-2 opacity-60">
              {f === 'all' ? specialties.length : specialties.filter((s) => s.role === f).length}
            </span>
          </button>
        ))}
      </div>

      {isLoading ? (
        <div className="bg-white rounded-xl border border-gray-100 p-12 text-center text-gray-400">
          Loading specialties…
        </div>
      ) : filtered.length === 0 ? (
        <div className="bg-white rounded-xl border border-gray-100 p-12 text-center text-gray-400">
          <Stethoscope className="mx-auto mb-3 opacity-40" size={40} />
          <p className="font-medium">No specialties yet</p>
          <p className="text-xs mt-1">Add one above so providers can pick it during signup.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {filtered.map((s) => (
            <div
              key={s.specialty_id}
              className="bg-white rounded-2xl border border-gray-100 p-5 hover:border-sky-300 hover:shadow-md transition-all"
            >
              <div className="flex items-start justify-between mb-3">
                <div
                  className={`w-11 h-11 rounded-xl flex items-center justify-center ${
                    s.role === 'nurse' ? 'bg-orange-50 text-orange-500' : 'bg-sky-50 text-sky-600'
                  }`}
                >
                  {s.role === 'nurse' ? <HeartPulse size={20} /> : <Stethoscope size={20} />}
                </div>
                <button
                  onClick={() => {
                    if (confirm(`Delete "${s.name}"? This cannot be undone.`)) {
                      deleteMutation.mutate(s.specialty_id);
                    }
                  }}
                  className="text-gray-300 hover:text-red-500 transition"
                >
                  <Trash2 size={16} />
                </button>
              </div>
              <h3 className="text-base font-bold text-dark-900">{s.name}</h3>
              <p className="text-xs text-gray-500 mt-1 capitalize">{s.role}</p>
              {s.description && (
                <p className="text-sm text-gray-600 mt-3 line-clamp-2">{s.description}</p>
              )}
              <div className="mt-4 pt-3 border-t border-gray-100 flex items-center justify-between">
                <span
                  className={`text-xs font-semibold ${
                    s.is_active ? 'text-emerald-600' : 'text-gray-400'
                  }`}
                >
                  {s.is_active ? '● Active' : '○ Inactive'}
                </span>
                <button
                  onClick={() => toggleActive.mutate(s)}
                  className="text-xs text-sky-600 hover:text-sky-800 font-semibold"
                >
                  {s.is_active ? 'Disable' : 'Enable'}
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Add modal */}
      {isModalOpen && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center z-50">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md p-6 m-4">
            <div className="flex justify-between items-start mb-5">
              <div>
                <h3 className="text-lg font-bold text-dark-900">Add Specialty</h3>
                <p className="text-xs text-gray-500 mt-1">
                  Becomes available in the provider signup dropdown.
                </p>
              </div>
              <button
                onClick={() => setIsModalOpen(false)}
                className="text-gray-400 hover:text-dark-900"
              >
                <X size={20} />
              </button>
            </div>

            <div className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-dark-800 mb-2">
                  Name <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                  placeholder="e.g. Cardiology, Dental Nurse..."
                  className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:border-sky-500 focus:outline-none focus:ring-2 focus:ring-sky-100 text-sm"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-dark-800 mb-2">Role</label>
                <div className="grid grid-cols-2 gap-2">
                  {(['specialist', 'nurse'] as const).map((r) => (
                    <button
                      key={r}
                      onClick={() => setForm({ ...form, role: r })}
                      className={`py-3 rounded-xl text-sm font-semibold border capitalize transition ${
                        form.role === r
                          ? 'bg-dark-900 text-white border-dark-900'
                          : 'bg-white text-gray-600 border-gray-200 hover:border-dark-900'
                      }`}
                    >
                      {r}
                    </button>
                  ))}
                </div>
              </div>

              <div>
                <label className="block text-xs font-semibold text-dark-800 mb-2">
                  Description (optional)
                </label>
                <textarea
                  value={form.description}
                  onChange={(e) => setForm({ ...form, description: e.target.value })}
                  rows={3}
                  placeholder="Short description shown to providers..."
                  className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:border-sky-500 focus:outline-none focus:ring-2 focus:ring-sky-100 text-sm resize-none"
                />
              </div>

              {createMutation.isError && (
                <div className="bg-red-50 border border-red-200 text-red-700 px-3 py-2 rounded-lg text-xs">
                  {(createMutation.error as Error).message}
                </div>
              )}
            </div>

            <div className="flex space-x-2 mt-6">
              <button
                onClick={() => setIsModalOpen(false)}
                className="flex-1 py-3 rounded-xl border border-gray-200 text-gray-600 font-semibold text-sm hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                onClick={() => createMutation.mutate(form)}
                disabled={!form.name.trim() || createMutation.isPending}
                className="flex-1 py-3 rounded-xl text-white font-semibold text-sm transition-all disabled:opacity-60"
                style={{ background: 'linear-gradient(135deg, #1B4080, #0EA5E9)' }}
              >
                {createMutation.isPending ? 'Saving…' : 'Add Specialty'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Specialties;
