import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { Activity, Users, UserCheck, TrendingUp, CalendarClock, Wallet } from 'lucide-react';
import { API_BASE } from '../config';

interface DashboardStats {
  total_patients: number;
  total_providers: number;
  pending_verifications: number;
  total_consultations: number;
  total_revenue: number;
  pending_withdrawals: number;
}

interface RevenuePoint {
  date: string;
  revenue: number;
  volume: number;
  payments: number;
}

const authHeaders = () => ({
  'Content-Type': 'application/json',
  'Authorization': `Bearer ${localStorage.getItem('clinix_admin_token')}`,
});

const fetchDashboardStats = async (): Promise<DashboardStats> => {
  const res = await fetch(`${API_BASE}/admin/dashboard/`, { headers: authHeaders() });
  if (res.status === 401) {
    localStorage.removeItem('clinix_admin_token');
    window.location.href = '/login';
    throw new Error('Unauthorized');
  }
  if (!res.ok) throw new Error('Network response was not ok');
  return res.json();
};

const fetchRevenueSeries = async (days: number): Promise<RevenuePoint[]> => {
  const res = await fetch(`${API_BASE}/admin/analytics/revenue/?days=${days}`, { headers: authHeaders() });
  if (!res.ok) throw new Error('Failed to load revenue analytics');
  const body = await res.json();
  return body.data ?? [];
};

const RevenueChart = ({ points }: { points: RevenuePoint[] }) => {
  if (points.length === 0) {
    return (
      <div className="h-40 w-full bg-slate-50 rounded-2xl border border-dashed border-gray-200 flex flex-col items-center justify-center space-y-3">
        <div className="w-12 h-12 rounded-full bg-white flex items-center justify-center shadow-sm">
          <Activity size={20} className="text-sky-400" />
        </div>
        <p className="text-sm font-medium text-gray-400">No revenue activity in this period yet</p>
      </div>
    );
  }

  // SVG line chart with a soft area fill. Padding keeps the line and dots
  // off the edges; a single data point renders as a dot on a flat line.
  const W = 600;
  const H = 160;
  const PAD = 14;
  const max = Math.max(...points.map((p) => p.revenue), 1);
  const x = (i: number) =>
    points.length === 1 ? W / 2 : PAD + (i * (W - PAD * 2)) / (points.length - 1);
  const y = (v: number) => H - PAD - (v / max) * (H - PAD * 2);

  const linePath = points
    .map((p, i) => `${i === 0 ? 'M' : 'L'} ${x(i).toFixed(1)} ${y(p.revenue).toFixed(1)}`)
    .join(' ');
  const areaPath =
    `${linePath} L ${x(points.length - 1).toFixed(1)} ${H - PAD} L ${x(0).toFixed(1)} ${H - PAD} Z`;

  return (
    <div className="h-40 w-full bg-slate-50 rounded-2xl border border-gray-100 overflow-hidden">
      <svg viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="none" className="w-full h-full">
        <defs>
          <linearGradient id="revFill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#38bdf8" stopOpacity="0.35" />
            <stop offset="100%" stopColor="#38bdf8" stopOpacity="0.02" />
          </linearGradient>
        </defs>
        {points.length > 1 && <path d={areaPath} fill="url(#revFill)" />}
        <path d={linePath} fill="none" stroke="#0ea5e9" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />
        {points.map((p, i) => (
          <circle key={p.date} cx={x(i)} cy={y(p.revenue)} r={points.length > 40 ? 0 : 3.5} fill="#0284c7">
            <title>{`${p.date} — XAF ${p.revenue.toLocaleString()} (${p.payments} payment${p.payments === 1 ? '' : 's'})`}</title>
          </circle>
        ))}
      </svg>
    </div>
  );
};

const Dashboard = () => {
  const navigate = useNavigate();
  const [rangeDays, setRangeDays] = useState(30);

  const { data, isLoading } = useQuery<DashboardStats>({
    queryKey: ['dashboardStats'],
    queryFn: fetchDashboardStats,
  });

  const { data: revenueSeries = [] } = useQuery<RevenuePoint[]>({
    queryKey: ['revenueSeries', rangeDays],
    queryFn: () => fetchRevenueSeries(rangeDays),
  });

  if (isLoading) return (
    <div className="flex items-center justify-center h-64">
      <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-sky-500"></div>
    </div>
  );

  const stats = [
    { name: 'Total Patients', value: data?.total_patients, Icon: Users, color: 'text-sky-500', bg: 'bg-sky-50' },
    { name: 'Verified Providers', value: data?.total_providers, Icon: UserCheck, color: 'text-dark-500', bg: 'bg-dark-50' },
    { name: 'Pending Verifications', value: data?.pending_verifications, Icon: Activity, color: 'text-orange-500', bg: 'bg-orange-50' },
    { name: 'Total Consultations', value: data?.total_consultations, Icon: TrendingUp, color: 'text-emerald-500', bg: 'bg-emerald-50' },
  ];

  const periodRevenue = revenueSeries.reduce((sum, p) => sum + p.revenue, 0);

  const quickActions = [
    {
      label: 'Verify New Providers',
      count: data?.pending_verifications ?? null,
      primary: true,
      icon: <UserCheck size={16} />,
      onClick: () => navigate('/verifications'),
    },
    {
      label: 'Review Withdrawals',
      count: data?.pending_withdrawals ?? null,
      primary: false,
      icon: <Wallet size={16} />,
      onClick: () => navigate('/revenue'),
    },
    {
      label: 'View Appointments',
      count: null,
      primary: false,
      icon: <CalendarClock size={16} />,
      onClick: () => navigate('/appointments'),
    },
  ];

  return (
    <div className="space-y-8 animate-in fade-in duration-500">
      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {stats.map((stat, idx) => (
          <div key={idx} className="stat-card flex items-center space-x-4">
            <div className={`p-4 rounded-2xl ${stat.bg} ${stat.color}`}>
              <stat.Icon size={24} />
            </div>
            <div>
              <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider">{stat.name}</p>
              <p className="text-2xl font-bold text-dark-900">{stat.value?.toLocaleString()}</p>
            </div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Revenue Card */}
        <div className="lg:col-span-2 space-y-6">
          <div className="bg-white rounded-3xl shadow-sm border border-gray-100 p-8 overflow-hidden relative">
            <div className="absolute top-0 right-0 p-8 opacity-5">
              <TrendingUp size={160} className="text-dark-900" />
            </div>

            <div className="relative z-10">
              <div className="flex items-center justify-between mb-8">
                <div>
                  <h3 className="text-xl font-bold text-dark-900">Total Platform Revenue</h3>
                  <p className="text-gray-400 text-sm">
                    Selected period: <span className="text-emerald-500 font-semibold">XAF {periodRevenue.toLocaleString()}</span>
                  </p>
                </div>
                <select
                  value={rangeDays}
                  onChange={(e) => setRangeDays(Number(e.target.value))}
                  className="bg-slate-50 border-none rounded-xl px-4 py-2 text-sm font-medium focus:ring-2 focus:ring-sky-500"
                >
                  <option value={30}>Last 30 Days</option>
                  <option value={180}>Last 6 Months</option>
                  <option value={365}>Last 12 Months</option>
                </select>
              </div>

              <div className="flex items-baseline space-x-2 mb-8">
                <span className="text-sm font-bold text-gray-400">XAF</span>
                <p className="text-5xl font-black text-dark-900 tracking-tight">
                  {data?.total_revenue?.toLocaleString()}
                </p>
                <span className="text-xs font-medium text-gray-400">all time</span>
              </div>

              <RevenueChart points={revenueSeries} />
            </div>
          </div>

        </div>

        {/* Quick Actions Panel */}
        <div className="bg-dark-900 rounded-3xl shadow-2xl p-8 text-white relative overflow-hidden flex flex-col h-full">
          <div className="absolute -bottom-10 -right-10 w-40 h-40 bg-sky-500/10 rounded-full blur-3xl"></div>

          <h3 className="text-xl font-bold mb-6">Administrative Task List</h3>
          <div className="space-y-4 relative z-10 flex-1">
            {quickActions.map((action, i) => (
              <button
                key={i}
                onClick={action.onClick}
                className={`w-full flex items-center justify-between p-5 rounded-2xl transition-all hover:scale-[1.02] active:scale-95 ${action.primary ? 'bg-sky-500 shadow-lg shadow-sky-500/30' : 'bg-white/5 border border-white/10 hover:bg-white/10'}`}
              >
                <div className="flex items-center space-x-3">
                  {action.icon}
                  <span className="text-sm font-semibold">{action.label}</span>
                </div>
                {action.count !== null && (
                  <span className="bg-white/20 px-2.5 py-1 rounded-lg text-xs font-bold tracking-tighter">{action.count}</span>
                )}
              </button>
            ))}
          </div>

          <div className="mt-12 p-5 rounded-2xl bg-white/5 border border-white/10">
            <p className="text-sky-300 text-[10px] font-bold uppercase tracking-widest mb-2">Platform Health</p>
            <div className="flex items-center justify-between">
              <span className="text-sm font-medium">Core API</span>
              <span className="text-emerald-400 text-xs font-bold flex items-center"><span className="w-2 h-2 bg-emerald-400 rounded-full mr-2 animate-pulse"></span> Stable</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
