import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Plus, Trash2, Stethoscope, X, Users, Search } from 'lucide-react';
import { API_BASE } from '../config';

interface Specialty {
  specialty_id: string;
  name: string;
  description: string | null;
  is_active: boolean;
  created_at: string;
  provider_count: number;
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
  const [search, setSearch] = useState('');
  const [form, setForm] = useState({ name: '', description: '' });

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
      setForm({ name: '', description: '' });
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

  const filtered = specialties.filter(
    (s) => !search || s.name.toLowerCase().includes(search.toLowerCase()),
  );

  const totalProviders = specialties.reduce((sum, s) => sum + (s.provider_count || 0), 0);

  return (
    <div>
      {/* Header */}
      <div className="flex justify-between items-start mb-6">
        <div>
          <h2 className="text-2xl font-bold text-dark-900">Specialties</h2>
          <p className="text-gray-500 text-sm mt-1">
            Configure the specialties that doctors can pick when registering as a specialist.
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

      {/* Stat strip */}
      <div className="grid grid-cols-3 gap-3 mb-6">
        <div className="bg-white rounded-xl border border-gray-100 p-4">
          <p className="text-[11px] uppercase font-bold text-gray-500 tracking-wider">
            Total specialties
          </p>
          <p className="text-2xl font-extrabold text-dark-900 mt-1">{specialties.length}</p>
        </div>
        <div className="bg-white rounded-xl border border-gray-100 p-4">
          <p className="text-[11px] uppercase font-bold text-gray-500 tracking-wider">Active</p>
          <p className="text-2xl font-extrabold text-emerald-600 mt-1">
            {specialties.filter((s) => s.is_active).length}
          </p>
        </div>
        <div className="bg-white rounded-xl border border-gray-100 p-4">
          <p className="text-[11px] uppercase font-bold text-gray-500 tracking-wider">
            Specialists registered
          </p>
          <p className="text-2xl font-extrabold text-sky-600 mt-1">{totalProviders}</p>
        </div>
      </div>

      {/* Search */}
      <div className="relative mb-4">
        <Search
          size={16}
          className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400"
        />
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search specialties..."
          className="w-full pl-11 pr-4 py-3 rounded-xl border border-gray-200 bg-white text-sm focus:outline-none focus:border-sky-500 focus:ring-2 focus:ring-sky-100"
        />
      </div>

      {/* List */}
      {isLoading ? (
        <div className="bg-white rounded-xl border border-gray-100 p-12 text-center text-gray-400">
          Loading specialties…
        </div>
      ) : filtered.length === 0 ? (
        <div className="bg-white rounded-xl border border-gray-100 p-12 text-center text-gray-400">
          <Stethoscope className="mx-auto mb-3 opacity-40" size={40} />
          <p className="font-medium">
            {specialties.length === 0 ? 'No specialties yet' : 'No matches for your search'}
          </p>
          {specialties.length === 0 && (
            <p className="text-xs mt-1">Add one above so doctors can pick it during signup.</p>
          )}
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-gray-100 overflow-hidden">
          <div className="grid grid-cols-12 gap-2 px-5 py-3 bg-gray-50 border-b border-gray-100 text-[11px] font-bold uppercase tracking-wider text-gray-500">
            <div className="col-span-5">Specialty</div>
            <div className="col-span-3">Doctors registered</div>
            <div className="col-span-2">Status</div>
            <div className="col-span-2 text-right">Actions</div>
          </div>
          <ul className="divide-y divide-gray-100">
            {filtered.map((s) => (
              <li
                key={s.specialty_id}
                className="grid grid-cols-12 gap-2 items-center px-5 py-4 hover:bg-gray-50 transition"
              >
                {/* Name + description */}
                <div className="col-span-5 flex items-start space-x-3 min-w-0">
                  <div className="w-10 h-10 rounded-xl bg-sky-50 text-sky-600 flex items-center justify-center flex-shrink-0">
                    <Stethoscope size={18} />
                  </div>
                  <div className="min-w-0">
                    <p className="font-bold text-dark-900 truncate">{s.name}</p>
                    {s.description ? (
                      <p className="text-xs text-gray-500 mt-0.5 line-clamp-1">
                        {s.description}
                      </p>
                    ) : (
                      <p className="text-xs text-gray-300 italic mt-0.5">No description</p>
                    )}
                  </div>
                </div>

                {/* Provider count */}
                <div className="col-span-3 flex items-center space-x-2">
                  <div className="w-8 h-8 rounded-lg bg-dark-900/5 flex items-center justify-center">
                    <Users size={14} className="text-dark-900" />
                  </div>
                  <div>
                    <p className="text-base font-bold text-dark-900 leading-none">
                      {s.provider_count}
                    </p>
                    <p className="text-[10px] text-gray-400 mt-0.5">
                      {s.provider_count === 1 ? 'doctor' : 'doctors'}
                    </p>
                  </div>
                </div>

                {/* Status */}
                <div className="col-span-2">
                  <span
                    className={`inline-flex items-center px-2.5 py-1 rounded-full text-[11px] font-bold ${
                      s.is_active
                        ? 'bg-emerald-50 text-emerald-700'
                        : 'bg-gray-100 text-gray-500'
                    }`}
                  >
                    <span
                      className={`w-1.5 h-1.5 rounded-full mr-1.5 ${
                        s.is_active ? 'bg-emerald-500' : 'bg-gray-400'
                      }`}
                    />
                    {s.is_active ? 'Active' : 'Inactive'}
                  </span>
                </div>

                {/* Actions */}
                <div className="col-span-2 flex justify-end items-center space-x-2">
                  <button
                    onClick={() => toggleActive.mutate(s)}
                    className="text-xs font-bold text-sky-600 hover:text-sky-800 px-3 py-1.5 rounded-lg hover:bg-sky-50 transition"
                  >
                    {s.is_active ? 'Disable' : 'Enable'}
                  </button>
                  <button
                    onClick={() => {
                      if (s.provider_count > 0) {
                        alert(
                          `Cannot delete "${s.name}" — ${s.provider_count} doctor(s) currently use it. Disable instead.`,
                        );
                        return;
                      }
                      if (confirm(`Delete "${s.name}"? This cannot be undone.`)) {
                        deleteMutation.mutate(s.specialty_id);
                      }
                    }}
                    className={`p-2 rounded-lg transition ${
                      s.provider_count > 0
                        ? 'text-gray-200 cursor-not-allowed'
                        : 'text-gray-300 hover:text-red-500 hover:bg-red-50'
                    }`}
                  >
                    <Trash2 size={15} />
                  </button>
                </div>
              </li>
            ))}
          </ul>
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
                  Becomes available in the doctor signup dropdown.
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
                  placeholder="e.g. Cardiology, Pediatrics, Dermatology..."
                  className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:border-sky-500 focus:outline-none focus:ring-2 focus:ring-sky-100 text-sm"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-dark-800 mb-2">
                  Description (optional)
                </label>
                <textarea
                  value={form.description}
                  onChange={(e) => setForm({ ...form, description: e.target.value })}
                  rows={3}
                  placeholder="Short description shown to doctors..."
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
