import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  KeyRound,
  ShieldAlert,
  Trash2,
  Search,
  X,
  CheckCircle2,
  XCircle,
} from 'lucide-react';
import { API_BASE } from '../config';

interface ProviderInfo {
  provider_role: string;
  specialty: string;
  specialty_name: string | null;
  verification_status: string;
  license_number: string;
  consultation_fee: string;
}

interface User {
  user_id: string;
  email: string | null;
  phone_number: string | null;
  user_type: string;
  full_name: string | null;
  is_verified: boolean;
  provider: ProviderInfo | null;
}

const authHeader = () => ({
  Authorization: `Bearer ${localStorage.getItem('clinix_admin_token')}`,
});

const fetchUsers = async (filter: string, search: string): Promise<User[]> => {
  const params = new URLSearchParams();
  if (filter !== 'all') params.set('user_type', filter);
  if (search) params.set('search', search);
  const url = `${API_BASE}/admin/users/${params.toString() ? `?${params.toString()}` : ''}`;
  const res = await fetch(url, { headers: authHeader() });
  if (res.status === 401) {
    localStorage.removeItem('clinix_admin_token');
    window.location.href = '/login';
    return [];
  }
  if (!res.ok) throw new Error('Failed to fetch users');
  const data = await res.json();
  // The DRF list endpoint may be paginated or not.
  return Array.isArray(data) ? data : data.results || [];
};

const Users = () => {
  const qc = useQueryClient();
  const [filter, setFilter] = useState<'all' | 'patient' | 'provider' | 'superadmin'>('all');
  const [search, setSearch] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const [pwModalUser, setPwModalUser] = useState<User | null>(null);
  const [newPassword, setNewPassword] = useState('');
  const [pwError, setPwError] = useState('');

  // Debounce search
  if (search !== debouncedSearch) {
    setTimeout(() => {
      setDebouncedSearch(search);
    }, 300);
  }

  const { data: users = [], isLoading } = useQuery<User[]>({
    queryKey: ['users', filter, debouncedSearch],
    queryFn: () => fetchUsers(filter, debouncedSearch),
  });

  const deleteMutation = useMutation({
    mutationFn: async (id: string) => {
      const res = await fetch(`${API_BASE}/admin/users/${id}/`, {
        method: 'DELETE',
        headers: authHeader(),
      });
      if (!res.ok) throw new Error('Could not delete user');
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['users'] }),
  });

  const suspendMutation = useMutation({
    mutationFn: async ({ id, suspend }: { id: string; suspend: boolean }) => {
      const res = await fetch(`${API_BASE}/admin/users/${id}/`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', ...authHeader() },
        body: JSON.stringify({ is_active: !suspend ? true : false }),
      });
      if (!res.ok) throw new Error('Could not update user status');
      return res.json();
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['users'] }),
  });

  const resetPwMutation = useMutation({
    mutationFn: async ({ id, password }: { id: string; password: string }) => {
      const res = await fetch(`${API_BASE}/admin/users/${id}/reset-password/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...authHeader() },
        body: JSON.stringify({ password }),
      });
      if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        throw new Error(data.error || 'Could not reset password');
      }
      return res.json();
    },
    onSuccess: () => {
      setPwModalUser(null);
      setNewPassword('');
      setPwError('');
    },
    onError: (e: Error) => setPwError(e.message),
  });

  const stats = {
    total: users.length,
    providers: users.filter((u) => u.user_type === 'provider').length,
    patients: users.filter((u) => u.user_type === 'patient').length,
    admins: users.filter((u) => u.user_type === 'superadmin').length,
  };

  const handleDelete = (u: User) => {
    if (
      confirm(
        `Permanently delete ${u.full_name || u.email}? This will remove their account and all linked data.`,
      )
    ) {
      deleteMutation.mutate(u.user_id);
    }
  };

  const handleResetPassword = () => {
    setPwError('');
    if (!newPassword || newPassword.length < 6) {
      setPwError('Password must be at least 6 characters.');
      return;
    }
    if (pwModalUser) {
      resetPwMutation.mutate({ id: pwModalUser.user_id, password: newPassword });
    }
  };

  return (
    <div>
      {/* Header */}
      <div className="flex justify-between items-start mb-6">
        <div>
          <h2 className="text-2xl font-bold text-dark-900">User Directory</h2>
          <p className="text-gray-500 text-sm mt-1">
            All users in the system — search, edit, suspend, or remove.
          </p>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-4 gap-3 mb-6">
        <StatPill label="Total users" value={stats.total} color="dark-900" />
        <StatPill label="Providers" value={stats.providers} color="sky-600" />
        <StatPill label="Patients" value={stats.patients} color="emerald-600" />
        <StatPill label="Admins" value={stats.admins} color="orange-500" />
      </div>

      {/* Search + filter */}
      <div className="flex space-x-3 mb-4">
        <div className="relative flex-1">
          <Search
            size={16}
            className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400"
          />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by name, email, or phone..."
            className="w-full pl-11 pr-4 py-3 rounded-xl border border-gray-200 bg-white text-sm focus:outline-none focus:border-sky-500 focus:ring-2 focus:ring-sky-100"
          />
        </div>
        <select
          value={filter}
          onChange={(e) => setFilter(e.target.value as typeof filter)}
          className="border border-gray-200 rounded-xl px-4 py-3 text-sm font-medium bg-white focus:outline-none focus:ring-2 focus:ring-sky-100"
        >
          <option value="all">All roles</option>
          <option value="provider">Providers</option>
          <option value="patient">Patients</option>
          <option value="superadmin">Admins</option>
        </select>
      </div>

      {/* List */}
      {isLoading ? (
        <div className="bg-white rounded-xl border border-gray-100 p-12 text-center text-gray-400">
          Loading users…
        </div>
      ) : users.length === 0 ? (
        <div className="bg-white rounded-xl border border-gray-100 p-12 text-center text-gray-400">
          <ShieldAlert className="mx-auto mb-3 opacity-40" size={40} />
          <p className="font-medium">No users match your filter.</p>
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-gray-100 overflow-hidden">
          <div className="grid grid-cols-12 gap-2 px-5 py-3 bg-gray-50 border-b border-gray-100 text-[11px] font-bold uppercase tracking-wider text-gray-500">
            <div className="col-span-4">Name</div>
            <div className="col-span-3">Contact</div>
            <div className="col-span-2">Type / Specialty</div>
            <div className="col-span-1">Verified</div>
            <div className="col-span-2 text-right">Actions</div>
          </div>
          <ul className="divide-y divide-gray-100">
            {users.map((u) => (
              <li
                key={u.user_id}
                className="grid grid-cols-12 gap-2 items-center px-5 py-4 hover:bg-gray-50 transition"
              >
                {/* Name */}
                <div className="col-span-4 flex items-center space-x-3 min-w-0">
                  <div className="w-10 h-10 rounded-xl bg-dark-900 text-white font-bold flex items-center justify-center flex-shrink-0">
                    {(u.full_name || u.email || '?')[0].toUpperCase()}
                  </div>
                  <div className="min-w-0">
                    <p className="font-bold text-dark-900 truncate">
                      {u.full_name || '— no name —'}
                    </p>
                    <p className="text-[10px] font-mono text-gray-400 truncate">
                      {u.user_id}
                    </p>
                  </div>
                </div>

                {/* Contact */}
                <div className="col-span-3 min-w-0">
                  <p className="text-sm text-gray-700 truncate">{u.email || '—'}</p>
                  <p className="text-xs text-gray-400 truncate">
                    {u.phone_number || ''}
                  </p>
                </div>

                {/* Type */}
                <div className="col-span-2 min-w-0">
                  <span
                    className={`inline-flex px-2.5 py-1 rounded-md text-[10px] font-bold uppercase tracking-wide ${
                      u.user_type === 'provider'
                        ? 'bg-sky-50 text-sky-700'
                        : u.user_type === 'patient'
                        ? 'bg-emerald-50 text-emerald-700'
                        : u.user_type === 'superadmin'
                        ? 'bg-orange-50 text-orange-700'
                        : 'bg-gray-100 text-gray-500'
                    }`}
                  >
                    {u.user_type}
                  </span>
                  {u.provider && (
                    <p className="text-[11px] text-gray-500 mt-1 truncate">
                      {u.provider.provider_role === 'specialist'
                        ? (u.provider.specialty_name || u.provider.specialty)
                        : u.provider.provider_role}
                      {u.provider.verification_status !== 'approved' && (
                        <span className="ml-1 text-orange-500">
                          · {u.provider.verification_status}
                        </span>
                      )}
                    </p>
                  )}
                </div>

                {/* Verified */}
                <div className="col-span-1">
                  {u.is_verified ? (
                    <CheckCircle2 size={18} className="text-emerald-500" />
                  ) : (
                    <XCircle size={18} className="text-gray-300" />
                  )}
                </div>

                {/* Actions */}
                <div className="col-span-2 flex justify-end items-center space-x-1">
                  <button
                    title="Reset password"
                    onClick={() => {
                      setPwModalUser(u);
                      setNewPassword('');
                      setPwError('');
                    }}
                    className="p-2 text-gray-400 hover:text-sky-600 hover:bg-sky-50 rounded-lg transition"
                  >
                    <KeyRound size={15} />
                  </button>
                  <button
                    title="Suspend / unsuspend"
                    onClick={() =>
                      suspendMutation.mutate({ id: u.user_id, suspend: true })
                    }
                    className="p-2 text-gray-400 hover:text-orange-500 hover:bg-orange-50 rounded-lg transition"
                  >
                    <ShieldAlert size={15} />
                  </button>
                  <button
                    title="Delete"
                    onClick={() => handleDelete(u)}
                    className="p-2 text-gray-300 hover:text-red-500 hover:bg-red-50 rounded-lg transition"
                  >
                    <Trash2 size={15} />
                  </button>
                </div>
              </li>
            ))}
          </ul>
        </div>
      )}

      {/* Password reset modal */}
      {pwModalUser && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center z-50">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md p-6 m-4">
            <div className="flex justify-between items-start mb-4">
              <div>
                <h3 className="text-lg font-bold text-dark-900">Reset password</h3>
                <p className="text-xs text-gray-500 mt-1">
                  for <strong>{pwModalUser.full_name || pwModalUser.email}</strong>
                </p>
              </div>
              <button
                onClick={() => setPwModalUser(null)}
                className="text-gray-400 hover:text-dark-900"
              >
                <X size={20} />
              </button>
            </div>
            <input
              type="password"
              autoFocus
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              placeholder="New password (min 6 chars)"
              className="w-full px-4 py-3 rounded-xl border border-gray-200 focus:border-sky-500 focus:outline-none focus:ring-2 focus:ring-sky-100 text-sm"
            />
            {pwError && (
              <p className="mt-2 text-xs text-red-600">{pwError}</p>
            )}
            <div className="flex space-x-2 mt-5">
              <button
                onClick={() => setPwModalUser(null)}
                className="flex-1 py-3 rounded-xl border border-gray-200 text-gray-600 font-semibold text-sm hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                onClick={handleResetPassword}
                disabled={resetPwMutation.isPending}
                className="flex-1 py-3 rounded-xl text-white font-semibold text-sm transition-all disabled:opacity-60"
                style={{ background: 'linear-gradient(135deg, #1B4080, #0EA5E9)' }}
              >
                {resetPwMutation.isPending ? 'Saving…' : 'Update password'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

const StatPill = ({
  label,
  value,
  color,
}: {
  label: string;
  value: number;
  color: string;
}) => (
  <div className="bg-white rounded-xl border border-gray-100 p-4">
    <p className="text-[11px] uppercase font-bold text-gray-500 tracking-wider">
      {label}
    </p>
    <p className={`text-2xl font-extrabold mt-1 text-${color}`}>{value}</p>
  </div>
);

export default Users;
