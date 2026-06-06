import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Phone, MapPin, Building2, Save, X, Search } from 'lucide-react';
import { API_BASE } from '../config';

interface Facility {
  facility_name: string;
  address: string | null;
  city: string | null;
  phone_number: string | null;
  location_id: string;
}

const authHeader = () => ({
  Authorization: `Bearer ${localStorage.getItem('clinix_admin_token')}`,
});

const fetchFacilities = async (): Promise<Facility[]> => {
  const res = await fetch(`${API_BASE}/locations/facilities/`, { headers: authHeader() });
  if (res.status === 401) {
    localStorage.removeItem('clinix_admin_token');
    window.location.href = '/login';
    return [];
  }
  if (!res.ok) throw new Error('Failed to fetch facilities');
  const data = await res.json();
  return Array.isArray(data) ? data : [];
};

const Facilities = () => {
  const qc = useQueryClient();
  const [search, setSearch] = useState('');
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editingPhone, setEditingPhone] = useState('');

  const { data: facilities = [], isLoading } = useQuery<Facility[]>({
    queryKey: ['facilities'],
    queryFn: fetchFacilities,
  });

  const updatePhoneMutation = useMutation({
    mutationFn: async ({ locationId, phone }: { locationId: string; phone: string }) => {
      const res = await fetch(`${API_BASE}/locations/facilities/${locationId}/update-phone/`, {
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

  const handleStartEdit = (facility: Facility) => {
    setEditingId(facility.location_id);
    setEditingPhone(facility.phone_number || '');
  };

  const handleSavePhone = () => {
    if (editingId) {
      updatePhoneMutation.mutate({ locationId: editingId, phone: editingPhone });
    }
  };

  const handleCancelEdit = () => {
    setEditingId(null);
    setEditingPhone('');
  };

  const filteredFacilities = facilities.filter(f =>
    f.facility_name.toLowerCase().includes(search.toLowerCase()) ||
    f.city?.toLowerCase().includes(search.toLowerCase()) ||
    f.address?.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div>
      {/* Header */}
      <div className="flex justify-between items-start mb-6">
        <div>
          <h2 className="text-2xl font-bold text-dark-900">Facilities Directory</h2>
          <p className="text-gray-500 text-sm mt-1">
            Manage hospital and pharmacy contact information
          </p>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 gap-3 mb-6">
        <div className="bg-white rounded-xl border border-gray-100 p-4">
          <p className="text-[11px] uppercase font-bold text-gray-500 tracking-wider">Total Facilities</p>
          <p className="text-2xl font-extrabold mt-1 text-dark-900">{facilities.length}</p>
        </div>
        <div className="bg-white rounded-xl border border-gray-100 p-4">
          <p className="text-[11px] uppercase font-bold text-gray-500 tracking-wider">With Phone Numbers</p>
          <p className="text-2xl font-extrabold mt-1 text-sky-600">
            {facilities.filter(f => f.phone_number).length}
          </p>
        </div>
      </div>

      {/* Search */}
      <div className="mb-4">
        <div className="relative">
          <Search
            size={16}
            className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400"
          />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search facilities by name, city, or address..."
            className="w-full pl-11 pr-4 py-3 rounded-xl border border-gray-200 bg-white text-sm focus:outline-none focus:border-sky-500 focus:ring-2 focus:ring-sky-100"
          />
        </div>
      </div>

      {/* List */}
      {isLoading ? (
        <div className="bg-white rounded-xl border border-gray-100 p-12 text-center text-gray-400">
          Loading facilities…
        </div>
      ) : filteredFacilities.length === 0 ? (
        <div className="bg-white rounded-xl border border-gray-100 p-12 text-center text-gray-400">
          <Building2 className="mx-auto mb-3 opacity-40" size={40} />
          <p className="font-medium">No facilities found.</p>
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-gray-100 overflow-hidden">
          <div className="grid grid-cols-12 gap-2 px-5 py-3 bg-gray-50 border-b border-gray-100 text-[11px] font-bold uppercase tracking-wider text-gray-500">
            <div className="col-span-4">Facility Name</div>
            <div className="col-span-3">Location</div>
            <div className="col-span-3">Phone Number</div>
            <div className="col-span-2 text-right">Actions</div>
          </div>
          <ul className="divide-y divide-gray-100">
            {filteredFacilities.map((facility) => (
              <li
                key={facility.location_id}
                className="grid grid-cols-12 gap-2 items-center px-5 py-4 hover:bg-gray-50 transition"
              >
                {/* Facility Name */}
                <div className="col-span-4 min-w-0">
                  <div className="flex items-center space-x-3">
                    <div className="w-10 h-10 rounded-xl bg-sky-50 text-sky-600 flex items-center justify-center flex-shrink-0">
                      <Building2 size={18} />
                    </div>
                    <div className="min-w-0">
                      <p className="font-bold text-dark-900 truncate">
                        {facility.facility_name}
                      </p>
                      <p className="text-[10px] font-mono text-gray-400 truncate">
                        {facility.location_id}
                      </p>
                    </div>
                  </div>
                </div>

                {/* Location */}
                <div className="col-span-3 min-w-0">
                  <div className="flex items-center space-x-1">
                    <MapPin size={14} className="text-gray-400 flex-shrink-0" />
                    <div className="min-w-0">
                      <p className="text-sm text-gray-700 truncate">{facility.city || '—'}</p>
                      <p className="text-xs text-gray-400 truncate">
                        {facility.address || 'No address'}
                      </p>
                    </div>
                  </div>
                </div>

                {/* Phone Number */}
                <div className="col-span-3 min-w-0">
                  {editingId === facility.location_id ? (
                    <input
                      type="text"
                      value={editingPhone}
                      onChange={(e) => setEditingPhone(e.target.value)}
                      placeholder="Enter phone number"
                      className="w-full px-3 py-2 rounded-lg border border-sky-300 focus:border-sky-500 focus:outline-none focus:ring-2 focus:ring-sky-100 text-sm"
                      autoFocus
                    />
                  ) : (
                    <div className="flex items-center space-x-1">
                      <Phone size={14} className="text-gray-400 flex-shrink-0" />
                      <p className="text-sm text-gray-700 truncate">
                        {facility.phone_number || <span className="text-gray-400 italic">Not set</span>}
                      </p>
                    </div>
                  )}
                </div>

                {/* Actions */}
                <div className="col-span-2 flex justify-end items-center space-x-1">
                  {editingId === facility.location_id ? (
                    <>
                      <button
                        onClick={handleCancelEdit}
                        className="p-2 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition"
                      >
                        <X size={15} />
                      </button>
                      <button
                        onClick={handleSavePhone}
                        disabled={updatePhoneMutation.isPending}
                        className="p-2 text-sky-600 hover:text-sky-700 hover:bg-sky-50 rounded-lg transition disabled:opacity-50"
                      >
                        <Save size={15} />
                      </button>
                    </>
                  ) : (
                    <button
                      onClick={() => handleStartEdit(facility)}
                      className="px-3 py-1.5 text-xs font-semibold text-sky-600 bg-sky-50 hover:bg-sky-100 rounded-lg transition"
                    >
                      Edit Phone
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
