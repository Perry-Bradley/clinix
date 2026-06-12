import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Search, Download, CalendarClock, Video, Home, FlaskConical, Stethoscope } from 'lucide-react';
import { API_BASE } from '../config';

interface Appointment {
  appointment_id: string;
  scheduled_at: string;
  appointment_type: string;
  status: string;
  reason_for_visit?: string;
  patient?: { user?: { full_name?: string } };
  provider?: { full_name?: string };
}

const STATUS_TABS = [
  { key: '', label: 'All' },
  { key: 'pending', label: 'Pending' },
  { key: 'confirmed', label: 'Confirmed' },
  { key: 'completed', label: 'Completed' },
  { key: 'cancelled', label: 'Cancelled' },
  { key: 'no_show', label: 'No Show' },
];

const STATUS_STYLES: Record<string, string> = {
  pending: 'bg-orange-50 text-orange-600 border-orange-200',
  confirmed: 'bg-sky-50 text-sky-600 border-sky-200',
  completed: 'bg-emerald-50 text-emerald-600 border-emerald-200',
  cancelled: 'bg-red-50 text-red-600 border-red-200',
  no_show: 'bg-slate-100 text-slate-500 border-slate-200',
};

const TYPE_META: Record<string, { label: string; icon: React.ReactNode }> = {
  virtual: { label: 'Virtual', icon: <Video size={13} /> },
  'in-person': { label: 'In-Person', icon: <Stethoscope size={13} /> },
  lab_test: { label: 'Lab Test', icon: <FlaskConical size={13} /> },
  home_treatment: { label: 'Home Care', icon: <Home size={13} /> },
};

const authHeaders = () => ({
  'Authorization': `Bearer ${localStorage.getItem('clinix_admin_token')}`,
});

const fetchAppointments = async (status: string, search: string): Promise<Appointment[]> => {
  const params = new URLSearchParams();
  if (status) params.set('status', status);
  if (search) params.set('search', search);
  const res = await fetch(`${API_BASE}/admin/appointments/?${params}`, { headers: authHeaders() });
  if (res.status === 401) {
    localStorage.removeItem('clinix_admin_token');
    window.location.href = '/login';
    return [];
  }
  if (!res.ok) throw new Error('Failed to fetch appointments');
  const body = await res.json();
  return Array.isArray(body) ? body : body.results ?? [];
};

const exportCsv = async () => {
  const res = await fetch(`${API_BASE}/admin/reports/export/?report=appointments`, { headers: authHeaders() });
  if (!res.ok) return;
  const blob = await res.blob();
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'clinix_appointments.csv';
  a.click();
  URL.revokeObjectURL(url);
};

const formatWhen = (iso: string) => {
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '—';
  return d.toLocaleString(undefined, {
    day: 'numeric', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  });
};

const Appointments = () => {
  const [statusFilter, setStatusFilter] = useState('');
  const [search, setSearch] = useState('');
  const [submittedSearch, setSubmittedSearch] = useState('');

  const { data: appointments = [], isLoading } = useQuery<Appointment[]>({
    queryKey: ['adminAppointments', statusFilter, submittedSearch],
    queryFn: () => fetchAppointments(statusFilter, submittedSearch),
  });

  // Status distribution for the summary strip (within the current search scope,
  // so fetch unfiltered counts only when no status filter is applied).
  const counts = appointments.reduce<Record<string, number>>((acc, a) => {
    acc[a.status] = (acc[a.status] ?? 0) + 1;
    return acc;
  }, {});

  return (
    <div className="space-y-5 animate-in fade-in duration-500">
      {/* Header row */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h3 className="text-lg font-bold text-slate-900">Appointments</h3>
          <p className="text-slate-400 text-xs">Every booking on the platform with its current status</p>
        </div>
        <div className="flex items-center gap-2">
          <form
            onSubmit={(e) => { e.preventDefault(); setSubmittedSearch(search.trim()); }}
            className="relative"
          >
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search patient or doctor…"
              className="pl-9 pr-3 py-2 text-sm rounded-xl border border-slate-200 bg-white focus:outline-none focus:ring-2 focus:ring-sky-500 w-64"
            />
          </form>
          <button
            onClick={exportCsv}
            className="flex items-center gap-2 px-3 py-2 text-sm font-semibold rounded-xl border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 transition-colors"
          >
            <Download size={14} /> Export CSV
          </button>
        </div>
      </div>

      {/* Status tabs */}
      <div className="flex flex-wrap gap-2">
        {STATUS_TABS.map((t) => {
          const active = statusFilter === t.key;
          const count = t.key === '' ? appointments.length : counts[t.key];
          return (
            <button
              key={t.key}
              onClick={() => setStatusFilter(t.key)}
              className={`px-4 py-1.5 rounded-full text-xs font-semibold border transition-colors ${
                active
                  ? 'bg-slate-900 text-white border-slate-900'
                  : 'bg-white text-slate-500 border-slate-200 hover:bg-slate-50'
              }`}
            >
              {t.label}
              {statusFilter === '' && count !== undefined && count > 0 && t.key !== '' && (
                <span className="ml-1.5 opacity-60">{count}</span>
              )}
            </button>
          );
        })}
      </div>

      {/* Table */}
      <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden">
        {isLoading ? (
          <div className="flex items-center justify-center h-48">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-sky-500"></div>
          </div>
        ) : appointments.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-16 text-slate-400">
            <CalendarClock size={36} className="mb-3 text-slate-300" />
            <p className="text-sm font-medium">No appointments found</p>
          </div>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-100 text-left text-[11px] uppercase tracking-wider text-slate-400">
                <th className="px-5 py-3 font-semibold">Patient</th>
                <th className="px-5 py-3 font-semibold">Provider</th>
                <th className="px-5 py-3 font-semibold">Type</th>
                <th className="px-5 py-3 font-semibold">Scheduled</th>
                <th className="px-5 py-3 font-semibold">Status</th>
              </tr>
            </thead>
            <tbody>
              {appointments.map((a) => {
                const type = TYPE_META[a.appointment_type] ?? { label: a.appointment_type, icon: <CalendarClock size={13} /> };
                const badge = STATUS_STYLES[a.status] ?? 'bg-slate-100 text-slate-500 border-slate-200';
                return (
                  <tr key={a.appointment_id} className="border-b border-slate-50 last:border-0 hover:bg-slate-50/60 transition-colors">
                    <td className="px-5 py-3.5 font-semibold text-slate-800">
                      {a.patient?.user?.full_name || '—'}
                    </td>
                    <td className="px-5 py-3.5 text-slate-600">{a.provider?.full_name || '—'}</td>
                    <td className="px-5 py-3.5">
                      <span className="inline-flex items-center gap-1.5 text-slate-600 text-xs font-medium">
                        {type.icon} {type.label}
                      </span>
                    </td>
                    <td className="px-5 py-3.5 text-slate-500 text-xs">{formatWhen(a.scheduled_at)}</td>
                    <td className="px-5 py-3.5">
                      <span className={`inline-block px-2.5 py-1 rounded-lg text-[11px] font-bold border capitalize ${badge}`}>
                        {a.status.replace('_', ' ')}
                      </span>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
};

export default Appointments;
