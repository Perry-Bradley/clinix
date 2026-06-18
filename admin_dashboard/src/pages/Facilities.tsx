import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Phone, MapPin, Building2, Save, X, Search, RefreshCw, Pill, Hospital } from 'lucide-react';
import { API_BASE } from '../config';

interface Facility {
  id: number;
  place_id: string;
  name: string;
  place_type: 'pharmacy' | 'hospital';
  address: string | null;
  city: string | null;
  phone_number: string | null;
  latitude: string | null;
  longitude: string | null;
  synced_at: string;
}

const authHeader = () => ({
  Authorization: `Bearer ${localStorage.getItem('clinix_admin_token')}`,
});

const fetchFacilities = async (type?: string): Promise<Facility[]> => {
  const url = type
    ? `${API_BASE}/admin/facilities/?type=${type}`
    : `${API_BASE}/admin/facilities/`;
  const res = await fetch(url, { headers: authHeader() });
  if (res.status === 401) {
    localStorage.removeItem('clinix_admin_token');
    window.location.href = '/login';
    return [];
  }
  if (!res.ok) throw new Error('Failed to fetch facilities');
  const data = await res.json();
  return Array.isArray(data) ? data : [];
};

type TabType = 'all' | 'pharmacy' | 'hospital';

const Facilities = () => {
  const qc = useQueryClient();
  const [search, setSearch] = useState('');
  const [activeTab, setActiveTab] = useState<TabType>('all');
  const [editingId, setEditingId] = useState<number | null>(null);
  const [editingPhone, setEditingPhone] = useState('');
  const [syncStatus, setSyncStatus] = useState<string | null>(null);

  const { data: facilities = [], isLoading } = useQuery<Facility[]>({
    queryKey: ['facilities'],
    queryFn: () => fetchFacilities(),
  });

  const syncMutation = useMutation({
    mutationFn: async () => {
      const res = await fetch(`${API_BASE}/admin/facilities/sync/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...authHeader() },
      });
      if (!res.ok) throw new Error('Sync failed');
      return res.json();
    },
    onSuccess: (data) => {
      qc.invalidateQueries({ queryKey: ['facilities'] });
      setSyncStatus(`Sync complete: ${data.created} new, ${data.updated} updated (${data.total} total)`);
      setTimeout(() => setSyncStatus(null), 5000);
    },
    onError: () => {
      setSyncStatus('Sync failed. Check GOOGLE_MAPS_API_KEY in Railway env vars.');
      setTimeout(() => setSyncStatus(null), 5000);
    },
  });

  const updatePhoneMutation = useMutation({
    mutationFn: async ({ id, phone }: { id: number; phone: string }) => {
      const res = await fetch(`${API_BASE}/admin/facilities/${id}/phone/`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', ...authHeader() },
        body: JSON.stringify({ phone_number: phone }),
      });
      if (!res.ok) throw new Error('Could not update phone number');
      return res.json();
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['facilities'] });
      setEditingId(null);
      setEditingPhone('');
    },
  });

  const tabFiltered = activeTab === 'all'
    ? facilities
    : facilities.filter(f => f.place_type === activeTab);

  const filtered = tabFiltered.filter(f =>
    f.name.toLowerCase().includes(search.toLowerCase()) ||
    f.city?.toLowerCase().includes(search.toLowerCase()) ||
    f.address?.toLowerCase().includes(search.toLowerCase())
  );

  const pharmacyCount = facilities.filter(f => f.place_type === 'pharmacy').length;
  const hospitalCount = facilities.filter(f => f.place_type === 'hospital').length;
  const withPhone = facilities.filter(f => f.phone_number).length;

  return (
    <div>
      {/* Header */}
      <div className="flex justify-between items-start mb-6">
        <div>
          <h2 className="text-2xl font-bold text-dark-900">Facilities Directory</h2>
          <p className="text-gray-500 text-sm mt-1">
            Pharmacies and hospitals sourced from Google Maps
          </p>
        </div>
        <button
          onClick={() => syncMutation.mutate()}
          disabled={syncMutation.isPending}
          className="flex items-center space-x-2 px-4 py-2 bg-sky-600 text-white text-sm font-semibold rounded-xl hover:bg-sky-700 transition disabled:opacity-60"
        >
          <RefreshCw size={15} className={syncMutation.isPending ? 'animate-spin' : ''} />
          <span>{syncMutation.isPending ? 'Syncing…' : 'Sync from Google Maps'}</span>
        </button>
      </div>

      {/* Sync status banner */}
      {syncStatus && (
        <div className="mb-4 px-4 py-3 bg-sky-50 border border-sky-200 rounded-xl text-sm text-sky-700 font-medium">
          {syncStatus}
        </div>
      )}

      {/* Stats */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-6">
        <div className="bg-white rounded-xl border border-gray-100 p-4">
          <p className="text-[11px] uppercase font-bold text-gray-500 tracking-wider">Total</p>
          <p className="text-2xl font-extrabold mt-1 text-dark-900">{facilities.length}</p>
        </div>
        <div className="bg-white rounded-xl border border-gray-100 p-4">
          <p className="text-[11px] uppercase font-bold text-gray-500 tracking-wider">Pharmacies</p>
          <p className="text-2xl font-extrabold mt-1 text-emerald-600">{pharmacyCount}</p>
        </div>
        <div className="bg-white rounded-xl border border-gray-100 p-4">
          <p className="text-[11px] uppercase font-bold text-gray-500 tracking-wider">Hospitals</p>
          <p className="text-2xl font-extrabold mt-1 text-blue-600">{hospitalCount}</p>
        </div>
        <div className="bg-white rounded-xl border border-gray-100 p-4">
          <p className="text-[11px] uppercase font-bold text-gray-500 tracking-wider">With Phone</p>
          <p className="text-2xl font-extrabold mt-1 text-sky-600">{withPhone}</p>
        </div>
      </div>

      {/* Tabs + Search */}
      <div className="flex flex-col sm:flex-row sm:items-center gap-3 mb-4">
        <div className="flex bg-gray-100 rounded-xl p-1 text-sm font-semibold">
          {(['all', 'pharmacy', 'hospital'] as TabType[]).map(tab => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`px-4 py-1.5 rounded-lg capitalize transition ${
                activeTab === tab
                  ? 'bg-white text-sky-700 shadow-sm'
                  : 'text-gray-500 hover:text-gray-700'
              }`}
            >
              {tab === 'all' ? 'All' : tab === 'pharmacy' ? 'Pharmacies' : 'Hospitals'}
            </button>
          ))}
        </div>
        <div className="relative flex-1">
          <Search size={15} className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by name, city, or address…"
            className="w-full pl-10 pr-4 py-2.5 rounded-xl border border-gray-200 bg-white text-sm focus:outline-none focus:border-sky-500 focus:ring-2 focus:ring-sky-100"
          />
        </div>
      </div>

      {/* List */}
      {isLoading ? (
        <div className="bg-white rounded-xl border border-gray-100 p-12 text-center text-gray-400">
          Loading facilities…
        </div>
      ) : facilities.length === 0 ? (
        <div className="bg-white rounded-xl border border-gray-100 p-12 text-center text-gray-400">
          <Building2 className="mx-auto mb-3 opacity-40" size={40} />
          <p className="font-semibold mb-1">No facilities yet</p>
          <p className="text-sm">Click "Sync from Google Maps" to populate the directory.</p>
        </div>
      ) : filtered.length === 0 ? (
        <div className="bg-white rounded-xl border border-gray-100 p-12 text-center text-gray-400">
          <p className="font-medium">No results for "{search}"</p>
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-gray-100 overflow-x-auto">
          <div className="grid grid-cols-12 gap-2 px-5 py-3 bg-gray-50 border-b border-gray-100 text-[11px] font-bold uppercase tracking-wider text-gray-500 min-w-[720px]">
            <div className="col-span-1">Type</div>
            <div className="col-span-4">Name</div>
            <div className="col-span-3">Location</div>
            <div className="col-span-3">Phone Number</div>
            <div className="col-span-1 text-right">Edit</div>
          </div>
          <ul className="divide-y divide-gray-100">
            {filtered.map((facility) => (
              <li
                key={facility.id}
                className="grid grid-cols-12 gap-2 items-center px-5 py-4 hover:bg-gray-50 transition min-w-[720px]"
              >
                {/* Type badge */}
                <div className="col-span-1">
                  {facility.place_type === 'pharmacy' ? (
                    <div className="w-8 h-8 rounded-lg bg-emerald-50 text-emerald-600 flex items-center justify-center" title="Pharmacy">
                      <Pill size={15} />
                    </div>
                  ) : (
                    <div className="w-8 h-8 rounded-lg bg-blue-50 text-blue-600 flex items-center justify-center" title="Hospital">
                      <Hospital size={15} />
                    </div>
                  )}
                </div>

                {/* Name */}
                <div className="col-span-4 min-w-0">
                  <p className="font-semibold text-dark-900 truncate">{facility.name}</p>
                  <p className="text-[10px] text-gray-400 truncate">{facility.place_id}</p>
                </div>

                {/* Location */}
                <div className="col-span-3 min-w-0">
                  <div className="flex items-start space-x-1">
                    <MapPin size={13} className="text-gray-400 flex-shrink-0 mt-0.5" />
                    <div className="min-w-0">
                      <p className="text-sm text-gray-700 truncate">{facility.city || '—'}</p>
                      <p className="text-xs text-gray-400 truncate">{facility.address || 'No address'}</p>
                    </div>
                  </div>
                </div>

                {/* Phone */}
                <div className="col-span-3 min-w-0">
                  {editingId === facility.id ? (
                    <input
                      type="text"
                      value={editingPhone}
                      onChange={(e) => setEditingPhone(e.target.value)}
                      placeholder="+237 6XX XXX XXX"
                      className="w-full px-3 py-1.5 rounded-lg border border-sky-300 focus:border-sky-500 focus:outline-none focus:ring-2 focus:ring-sky-100 text-sm"
                      autoFocus
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') updatePhoneMutation.mutate({ id: facility.id, phone: editingPhone });
                        if (e.key === 'Escape') { setEditingId(null); setEditingPhone(''); }
                      }}
                    />
                  ) : (
                    <div className="flex items-center space-x-1">
                      <Phone size={13} className="text-gray-400 flex-shrink-0" />
                      <p className="text-sm truncate">
                        {facility.phone_number
                          ? <span className="text-gray-700">{facility.phone_number}</span>
                          : <span className="text-gray-400 italic">Not set</span>
                        }
                      </p>
                    </div>
                  )}
                </div>

                {/* Actions */}
                <div className="col-span-1 flex justify-end items-center space-x-1">
                  {editingId === facility.id ? (
                    <>
                      <button
                        onClick={() => { setEditingId(null); setEditingPhone(''); }}
                        className="p-1.5 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition"
                      >
                        <X size={14} />
                      </button>
                      <button
                        onClick={() => updatePhoneMutation.mutate({ id: facility.id, phone: editingPhone })}
                        disabled={updatePhoneMutation.isPending}
                        className="p-1.5 text-sky-600 hover:text-sky-700 hover:bg-sky-50 rounded-lg transition disabled:opacity-50"
                      >
                        <Save size={14} />
                      </button>
                    </>
                  ) : (
                    <button
                      onClick={() => { setEditingId(facility.id); setEditingPhone(facility.phone_number || ''); }}
                      className="p-1.5 text-gray-400 hover:text-sky-600 hover:bg-sky-50 rounded-lg transition"
                    >
                      <Phone size={14} />
                    </button>
                  )}
                </div>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
};

export default Facilities;
