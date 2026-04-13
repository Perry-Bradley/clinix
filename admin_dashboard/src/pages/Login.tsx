import { useState } from 'react';
import { useNavigate } from 'react-router-dom';

// Database-backed authentication active

const Login = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const res = await fetch('http://127.0.0.1:8000/api/v1/auth/login/', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ identifier: email, password })
      });

      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error || 'Invalid credentials');
      }

      const data = await res.json();
      
      // Ensure only admins can access the dashboard
      if (data.user_type !== 'superadmin' && data.user_type !== 'admin') {
        throw new Error('Access denied. Administrator privileges required.');
      }

      localStorage.setItem('clinix_admin_token', data.access);
      localStorage.setItem('clinix_admin_user', JSON.stringify(data));
      navigate('/');
    } catch (err: any) {
      setError(err.message || 'Failed to connect to authentication server');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex">
      {/* Left Panel - Branding */}
      <div
        className="hidden lg:flex w-1/2 flex-col justify-between p-12"
        style={{ background: 'linear-gradient(135deg, #0A1628 0%, #102A50 50%, #0284C7 100%)' }}
      >
        <div className="flex items-center space-x-3">
          <div className="w-10 h-10 rounded-xl bg-sky-500 flex items-center justify-center shadow-lg shadow-sky-500/40">
            <span className="text-xl">🏥</span>
          </div>
          <span className="text-white font-bold text-xl">Clinix</span>
        </div>

        <div>
          <h2 className="text-4xl font-extrabold text-white leading-tight mb-4">
            Healthcare<br />
            <span className="text-sky-400">Management</span><br />
            Platform
          </h2>
          <p className="text-sky-200 text-base leading-relaxed max-w-sm">
            Manage patients, doctors, appointments, payments, and analytics — all from a single, powerful dashboard.
          </p>

          <div className="mt-10 grid grid-cols-2 gap-4">
            {[
              { label: 'Total Patients', value: '1,250+' },
              { label: 'Active Doctors', value: '45' },
              { label: 'Daily Consults', value: '120' },
              { label: 'Platform Revenue', value: 'XAF 154K' },
            ].map((s) => (
              <div key={s.label} className="bg-white/10 backdrop-blur rounded-xl p-4 border border-white/10">
                <p className="text-sky-300 text-xs font-medium">{s.label}</p>
                <p className="text-white text-xl font-bold mt-1">{s.value}</p>
              </div>
            ))}
          </div>
        </div>

        <p className="text-sky-400/60 text-xs">© 2026 Clinix Healthcare — Cameroon</p>
      </div>

      {/* Right Panel - Login Form */}
      <div className="flex-1 flex items-center justify-center bg-slate-50 px-8">
        <div className="w-full max-w-md">
          <div className="mb-8">
            <h1 className="text-3xl font-extrabold text-dark-900 mb-2">Welcome back 👋</h1>
            <p className="text-gray-500 text-sm">Sign in to your admin account to continue</p>
          </div>

          <form onSubmit={handleLogin} className="space-y-5">
            <div>
              <label className="block text-sm font-semibold text-dark-800 mb-2">Email address</label>
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="admin@clinix.cm"
                className="w-full px-4 py-3.5 rounded-xl border border-gray-200 bg-white text-dark-900 focus:outline-none focus:ring-2 focus:ring-sky-500 focus:border-transparent text-sm transition"
              />
            </div>

            <div>
              <label className="block text-sm font-semibold text-dark-800 mb-2">Password</label>
              <input
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••••"
                className="w-full px-4 py-3.5 rounded-xl border border-gray-200 bg-white text-dark-900 focus:outline-none focus:ring-2 focus:ring-sky-500 focus:border-transparent text-sm transition"
              />
            </div>

            {error && (
              <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-xl text-sm">
                {error}
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full py-3.5 rounded-xl font-semibold text-white text-sm transition-all duration-200 disabled:opacity-60"
              style={{ background: loading ? '#94a3b8' : 'linear-gradient(135deg, #1B4080, #0EA5E9)' }}
            >
              {loading ? 'Signing in...' : 'Sign in to Dashboard →'}
            </button>
          </form>

          {/* Credential Hint */}
          <div className="mt-8 p-4 rounded-xl border border-sky-200 bg-sky-50">
            <p className="text-sky-700 text-xs font-semibold mb-2">🔑 Demo Credentials</p>
            <div className="space-y-1.5">
              <div className="flex justify-between text-xs">
                <span className="text-gray-500">Email:</span>
                <code className="text-dark-800 font-mono font-semibold">admin@clinix.cm</code>
              </div>
              <div className="flex justify-between text-xs">
                <span className="text-gray-500">Password:</span>
                <code className="text-dark-800 font-mono font-semibold">Admin@2026</code>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Login;
