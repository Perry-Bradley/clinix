import { useState, useEffect } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Activity, Users, UserCheck, DollarSign, TrendingUp, Settings, Save, RefreshCw } from 'lucide-react';

interface DashboardStats {
  total_patients: number;
  total_providers: number;
  pending_verifications: number;
  total_consultations: number;
  total_revenue: number;
  global_fee: number;
}

const fetchDashboardStats = async (): Promise<DashboardStats> => {
  const token = localStorage.getItem('clinix_admin_token');
  const headers = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  };

  try {
    const res = await fetch('http://127.0.0.1:8000/api/v1/admin/dashboard/', { headers });
    if (res.status === 401) {
      localStorage.removeItem('clinix_admin_token');
      window.location.href = '/login';
      throw new Error('Unauthorized');
    }
    if (!res.ok) throw new Error('Network response was not ok');
    const data = await res.json();
    
    // Also fetch global fee
    const feeRes = await fetch('http://127.0.0.1:8000/api/v1/system/settings/fee/', { headers });
    const feeData = feeRes.ok ? await feeRes.json() : { consultation_fee: 15000 };
    
    return {
      total_patients: data.total_patients,
      total_providers: data.total_providers,
      pending_verifications: data.pending_verifications,
      total_consultations: data.total_consultations,
      total_revenue: data.total_revenue,
      global_fee: feeData.consultation_fee,
    };
  } catch (error) {
    console.error("Failed fetching dashboard stats:", error);
    return {
      total_patients: 0,
      total_providers: 0,
      pending_verifications: 0,
      total_consultations: 0,
      total_revenue: 0,
      global_fee: 15000,
    };
  }
};

const Dashboard = () => {
  const [platformFee, setPlatformFee] = useState(15000);
  const [isUpdating, setIsUpdating] = useState(false);

  const { data, isLoading } = useQuery<DashboardStats>({
    queryKey: ['dashboardStats'],
    queryFn: fetchDashboardStats,
  });

  // Sync state once data loads
  useEffect(() => {
    if (data?.global_fee) {
      setPlatformFee(data.global_fee);
    }
  }, [data?.global_fee]);

  const handleUpdateFee = async () => {
    setIsUpdating(true);
    const token = localStorage.getItem('clinix_admin_token');
    try {
      const res = await fetch('http://127.0.0.1:8000/api/v1/system/settings/fee/', {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ consultation_fee: platformFee })
      });
      if (!res.ok) throw new Error('Update failed');
      alert(`Success: Platform Fee updated to ${platformFee.toLocaleString()} XAF`);
    } catch (error) {
      alert('Failed to update platform fee');
      console.error(error);
    } finally {
      setIsUpdating(false);
    }
  };

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
              <DollarSign size={160} className="text-dark-900" />
            </div>
            
            <div className="relative z-10">
              <div className="flex items-center justify-between mb-8">
                <div>
                  <h3 className="text-xl font-bold text-dark-900">Total Platform Revenue</h3>
                  <p className="text-gray-400 text-sm">Monthly growth: <span className="text-emerald-500 font-semibold">+12.5%</span></p>
                </div>
                <select className="bg-slate-50 border-none rounded-xl px-4 py-2 text-sm font-medium focus:ring-2 focus:ring-sky-500">
                  <option>Last 30 Days</option>
                  <option>Last 6 Months</option>
                  <option>All Time</option>
                </select>
              </div>

              <div className="flex items-baseline space-x-2 mb-8">
                <span className="text-sm font-bold text-gray-400">XAF</span>
                <p className="text-5xl font-black text-dark-900 tracking-tight">
                  {data?.total_revenue?.toLocaleString()}
                </p>
              </div>

              <div className="h-40 w-full bg-slate-50 rounded-2xl border border-dashed border-gray-200 flex flex-col items-center justify-center space-y-3">
                <div className="w-12 h-12 rounded-full bg-white flex items-center justify-center shadow-sm">
                  <Activity size={20} className="text-sky-400" />
                </div>
                <p className="text-sm font-medium text-gray-400">Analytics Engine Connecting...</p>
              </div>
            </div>
          </div>

          {/* Fee Management Card */}
          <div className="bg-white rounded-3xl shadow-sm border border-orange-100 p-8 relative overflow-hidden">
            <div className="flex items-center space-x-3 mb-6">
              <div className="p-2.5 bg-orange-100 text-orange-600 rounded-xl">
                <Settings size={20} />
              </div>
              <div>
                <h3 className="text-lg font-bold text-dark-900">System Transaction Controls</h3>
                <p className="text-xs text-gray-400">Configure global consultation pricing</p>
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-8 items-end">
              <div>
                <label className="text-[10px] font-bold text-gray-400 uppercase tracking-widest block mb-2 ml-1">Universal Consultation Fee (XAF)</label>
                <div className="relative">
                  <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-gray-300 font-bold">XAF</div>
                  <input 
                    type="number"
                    value={platformFee}
                    onChange={(e) => setPlatformFee(Number(e.target.value))}
                    className="w-full pl-14 pr-4 py-3.5 bg-gray-50 border border-gray-100 rounded-2xl focus:ring-2 focus:ring-orange-400/20 focus:border-orange-400 outline-none transition-all font-bold text-dark-900"
                  />
                </div>
              </div>
              <div className="flex space-x-2">
                <button 
                  onClick={handleUpdateFee}
                  disabled={isUpdating}
                  className="flex-1 flex items-center justify-center space-x-2 px-6 py-3.5 bg-dark-900 text-white rounded-2xl font-bold text-sm hover:bg-dark-700 transition-all shadow-lg active:scale-95 disabled:opacity-50"
                >
                  {isUpdating ? <RefreshCw size={18} className="animate-spin" /> : <Save size={18} />}
                  <span>{isUpdating ? 'Updating...' : 'Save Changes'}</span>
                </button>
              </div>
            </div>
            
            <div className="mt-6 flex items-start space-x-3 p-4 bg-orange-50/50 rounded-2xl border border-orange-100/50">
              <TrendingUp size={16} className="text-orange-500 mt-0.5" />
              <p className="text-[11px] text-orange-700 font-medium">Changes here reflect immediately on the patient mobile checkout flow. Ensure consistency with regional medical standards.</p>
            </div>
          </div>
        </div>

        {/* Quick Actions Panel */}
        <div className="bg-dark-900 rounded-3xl shadow-2xl p-8 text-white relative overflow-hidden flex flex-col h-full">
          <div className="absolute -bottom-10 -right-10 w-40 h-40 bg-sky-500/10 rounded-full blur-3xl"></div>
          
          <h3 className="text-xl font-bold mb-6">Administrative Task List</h3>
          <div className="space-y-4 relative z-10 flex-1">
            {[
              { label: 'Verify New Providers', count: data?.pending_verifications, color: 'bg-sky-500', icon: <UserCheck size={16} /> },
              { label: 'Schedule System Sync', count: null, color: 'bg-white/10', icon: <Activity size={16} /> },
              { label: 'Generate Payout Report', count: null, color: 'bg-white/10', icon: <TrendingUp size={16} /> },
            ].map((action, i) => (
              <button
                key={i}
                className={`w-full flex items-center justify-between p-5 rounded-2xl transition-all hover:scale-[1.02] active:scale-95 ${action.color === 'bg-sky-500' ? 'bg-sky-500 shadow-lg shadow-sky-500/30' : 'bg-white/5 border border-white/10'}`}
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
