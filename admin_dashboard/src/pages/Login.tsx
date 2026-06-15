import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { API_BASE } from '../config';

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
      const res = await fetch(`${API_BASE}/auth/login/`, {
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
      {/* Left Panel - Branding (dark blue) */}
      <div
        className="hidden lg:flex w-1/2 flex-col justify-between p-12"
        style={{ background: 'linear-gradient(160deg, #0A1628 0%, #0F2547 55%, #1B4080 100%)' }}
      >
        <div className="flex items-center space-x-3">
          <img src="/clinix_logo.png" alt="Clinix" className="w-11 h-11 object-contain" />
          <div className="leading-tight">
            <span className="text-white font-bold text-xl">Clinix</span>
            <p className="text-blue-200/60 text-xs">Admin Portal</p>
          </div>
        </div>

        <div>
          <h2 className="text-4xl font-extrabold text-white leading-tight mb-4">
            Healthcare<br />
            <span className="text-blue-300">Management</span><br />
            Platform
          </h2>
          <p className="text-blue-200/80 text-base leading-relaxed max-w-sm">
            Manage patients, providers, appointments, payments and verifications — all from one secure dashboard.
          </p>
        </div>

        <p className="text-blue-300/40 text-xs">© 2026 Clinix Healthcare — Cameroon</p>
      </div>

      {/* Right Panel - Login Form */}
      <div className="flex-1 flex items-center justify-center bg-slate-50 px-8">
        <div className="w-full max-w-md">
          {/* Logo (shown here on small screens where the left panel is hidden) */}
          <div className="flex items-center space-x-3 mb-10 lg:hidden">
            <img src="/clinix_logo.png" alt="Clinix" className="w-10 h-10 object-contain" />
            <span className="font-bold text-xl text-[#0A1628]">Clinix</span>
          </div>

          <div className="mb-8">
            <h1 className="text-3xl font-extrabold text-[#0A1628] mb-2">Welcome back</h1>
            <p className="text-gray-500 text-sm">Sign in to your admin account to continue</p>
          </div>

          <form onSubmit={handleLogin} className="space-y-5">
            <div>
              <label className="block text-sm font-semibold text-[#1B2A45] mb-2">Email address</label>
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="admin@clinix.cm"
                className="w-full px-4 py-3.5 rounded-xl border border-gray-200 bg-white text-[#0A1628] focus:outline-none focus:ring-2 focus:ring-[#1B4080] focus:border-transparent text-sm transition"
              />
            </div>

            <div>
              <label className="block text-sm font-semibold text-[#1B2A45] mb-2">Password</label>
              <input
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••••"
                className="w-full px-4 py-3.5 rounded-xl border border-gray-200 bg-white text-[#0A1628] focus:outline-none focus:ring-2 focus:ring-[#1B4080] focus:border-transparent text-sm transition"
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
              className="w-full py-3.5 rounded-xl font-semibold text-white text-sm transition-all duration-200 hover:brightness-110 disabled:opacity-60"
              style={{ background: loading ? '#94a3b8' : '#1B4080' }}
            >
              {loading ? 'Signing in…' : 'Sign in to Dashboard'}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
};

export default Login;
