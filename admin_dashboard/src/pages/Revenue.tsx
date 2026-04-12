import { 
  DollarSign, 
  ArrowUpRight, 
  CheckCircle, 
  XCircle,
  CreditCard,
  Wallet
} from 'lucide-react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';

const Revenue = () => {
  const queryClient = useQueryClient();
  const token = localStorage.getItem('clinix_admin_token');

  // Fetch Summary Stats
  const { data: stats } = useQuery({
    queryKey: ['admin-stats'],
    queryFn: async () => {
      const res = await fetch('http://127.0.0.1:8000/api/v1/admin/dashboard/', {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      return res.json();
    }
  });

  // Fetch Withdrawals
  const { data: withdrawals, isLoading: loadingWithdrawals } = useQuery({
    queryKey: ['admin-withdrawals'],
    queryFn: async () => {
      const res = await fetch('http://127.0.0.1:8000/api/v1/admin/withdrawals/', {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      return res.json();
    }
  });

  // Withdrawal Action Mutation
  const actionMutation = useMutation({
    mutationFn: async ({ id, action }: { id: number, action: string }) => {
      const res = await fetch(`http://127.0.0.1:8000/api/v1/admin/withdrawals/${id}/action/`, {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}` 
        },
        body: JSON.stringify({ action })
      });
      return res.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-withdrawals'] });
      queryClient.invalidateQueries({ queryKey: ['admin-stats'] });
    }
  });

  return (
    <div className="space-y-8 animate-in fade-in duration-500">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Financial Management</h1>
        <p className="text-slate-500">Track platform revenue and manage provider payouts.</p>
      </div>

      {/* Stats Overview */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard 
          title="Total Revenue" 
          value={`XAF ${stats?.total_revenue?.toLocaleString() || '0'}`} 
          icon={<DollarSign className="w-6 h-6 text-emerald-600" />}
          trend="+12.5%"
          color="emerald"
        />
        <StatCard 
          title="Total Payouts" 
          value={`XAF ${stats?.total_payouts?.toLocaleString() || '0'}`} 
          icon={<CreditCard className="w-6 h-6 text-blue-600" />}
          trend="+4.2%"
          color="blue"
        />
        <StatCard 
          title="Pending Withdrawals" 
          value={stats?.pending_withdrawals?.toString() || '0'} 
          icon={<Wallet className="w-6 h-6 text-amber-600" />}
          trend="Action required"
          color="amber"
        />
        <StatCard 
          title="Net Platform Profit" 
          value={`XAF ${(stats?.total_revenue - stats?.total_payouts)?.toLocaleString() || '0'}`} 
          icon={<ArrowUpRight className="w-6 h-6 text-indigo-600" />}
          trend="+8.1%"
          color="indigo"
        />
      </div>

      {/* Withdrawal Requests Table */}
      <div className="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden">
        <div className="p-6 border-b border-slate-100 flex justify-between items-center">
          <h2 className="text-lg font-semibold text-slate-900">Withdrawal Requests</h2>
          <button className="text-sm font-medium text-slate-600 hover:text-slate-900">View All Transactions</button>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-slate-50/50">
                <th className="px-6 py-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">Provider</th>
                <th className="px-6 py-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">Amount</th>
                <th className="px-6 py-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">Method</th>
                <th className="px-6 py-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">Status</th>
                <th className="px-6 py-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">Date</th>
                <th className="px-6 py-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {loadingWithdrawals ? (
                 <tr><td colSpan={6} className="px-6 py-8 text-center text-slate-500">Loading requests...</td></tr>
              ) : withdrawals?.length === 0 ? (
                <tr><td colSpan={6} className="px-6 py-8 text-center text-slate-500">No pending withdrawal requests.</td></tr>
              ) : (
                withdrawals?.map((req: any) => (
                  <tr key={req.id} className="hover:bg-slate-50 transition-colors">
                    <td className="px-6 py-4">
                      <div className="font-medium text-slate-900">{req.provider_name}</div>
                      <div className="text-xs text-slate-500">{req.details}</div>
                    </td>
                    <td className="px-6 py-4 font-semibold text-slate-900">
                      XAF {req.amount?.toLocaleString()}
                    </td>
                    <td className="px-6 py-4">
                      <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-slate-100 text-slate-800 uppercase">
                        {req.method}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <StatusBadge status={req.status} />
                    </td>
                    <td className="px-6 py-4 text-sm text-slate-500">
                      {new Date(req.date).toLocaleDateString()}
                    </td>
                    <td className="px-6 py-4">
                      {req.status === 'pending' && (
                        <div className="flex gap-2">
                          <button 
                            onClick={() => actionMutation.mutate({ id: req.id, action: 'approve' })}
                            className="p-1.5 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                            title="Approve"
                          >
                            <CheckCircle className="w-5 h-5" />
                          </button>
                          <button 
                            onClick={() => actionMutation.mutate({ id: req.id, action: 'reject' })}
                            className="p-1.5 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                            title="Reject"
                          >
                            <XCircle className="w-5 h-5" />
                          </button>
                        </div>
                      )}
                      {req.status === 'approved' && (
                        <button 
                          onClick={() => actionMutation.mutate({ id: req.id, action: 'complete' })}
                          className="px-3 py-1.5 bg-emerald-600 text-white text-xs font-semibold rounded-lg hover:bg-emerald-700 transition-colors shadow-sm"
                        >
                          Mark Paid
                        </button>
                      )}
                      {req.status === 'completed' && (
                        <span className="text-xs font-medium text-slate-400">Completed</span>
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

const StatCard = ({ title, value, icon, trend, color }: any) => (
  <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
    <div className="flex justify-between items-start mb-4">
      <div className={`p-3 rounded-xl bg-${color}-50`}>
        {icon}
      </div>
      <div className="flex items-center gap-1 text-xs font-medium text-emerald-600 bg-emerald-50 px-2 py-1 rounded-full">
        <ArrowUpRight className="w-3 h-3" />
        {trend}
      </div>
    </div>
    <div className="text-2xl font-bold text-slate-900">{value}</div>
    <div className="text-sm font-medium text-slate-500 mt-1">{title}</div>
  </div>
);

const StatusBadge = ({ status }: { status: string }) => {
  const styles: any = {
    pending: 'bg-amber-50 text-amber-700 border-amber-100',
    approved: 'bg-blue-50 text-blue-700 border-blue-100',
    completed: 'bg-emerald-50 text-emerald-700 border-emerald-100',
    rejected: 'bg-red-50 text-red-700 border-red-100',
  };
  return (
    <span className={`px-2.5 py-0.5 rounded-full text-xs font-semibold border ${styles[status]}`}>
      {status.charAt(0).toUpperCase() + status.slice(1)}
    </span>
  );
};

export default Revenue;
