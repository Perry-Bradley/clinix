import { Outlet, Link, useNavigate, useLocation } from 'react-router-dom';
import { LayoutDashboard, Users, UserCheck, LogOut, Bell, HeartPulse, TrendingUp, FlaskConical, Stethoscope, Building2, CalendarClock } from 'lucide-react';

const Layout = () => {
  const navigate = useNavigate();
  const location = useLocation();

  const handleLogout = () => {
    localStorage.removeItem('clinix_admin_token');
    navigate('/login');
  };

  const menuItems = [
    { path: '/', icon: <LayoutDashboard size={18} />, label: 'Dashboard' },
    { path: '/patients', icon: <HeartPulse size={18} />, label: 'Patients' },
    { path: '/users', icon: <Users size={18} />, label: 'Users' },
    { path: '/verifications', icon: <UserCheck size={18} />, label: 'Verifications' },
    { path: '/appointments', icon: <CalendarClock size={18} />, label: 'Appointments' },
    { path: '/specialties', icon: <Stethoscope size={18} />, label: 'Specialties' },
    { path: '/facilities', icon: <Building2 size={18} />, label: 'Facilities' },
    { path: '/revenue', icon: <TrendingUp size={18} />, label: 'Finance' },
    { path: '/lab-tests', icon: <FlaskConical size={18} />, label: 'Lab Tests' },
  ];

  return (
    <div className="flex h-screen bg-slate-50 overflow-hidden">
      {/* Sidebar */}
      <aside className="w-60 bg-white border-r border-slate-200 flex flex-col flex-shrink-0">
        {/* Logo */}
        <div className="px-5 py-5 border-b border-slate-200">
          <div className="flex items-center space-x-3">
            <div className="w-8 h-8 rounded-lg bg-slate-900 flex items-center justify-center overflow-hidden">
              <img src="/clinix_logo.png" alt="Clinix" className="w-5 h-5 object-contain" />
            </div>
            <div>
              <h1 className="text-slate-900 font-bold text-base tracking-tight leading-none">Clinix</h1>
              <p className="text-slate-400 text-[11px] font-medium">Admin Portal</p>
            </div>
          </div>
        </div>

        {/* Nav */}
        <nav className="flex-1 px-3 py-4 space-y-0.5 overflow-y-auto">
          <p className="text-slate-400 text-[10px] font-semibold uppercase tracking-widest px-3 mb-2">Menu</p>
          {menuItems.map((item) => {
            const isActive = location.pathname === item.path;
            return (
              <Link key={item.path} to={item.path} className={isActive ? 'sidebar-link-active' : 'sidebar-link'}>
                {item.icon}
                <span className="font-medium text-sm">{item.label}</span>
              </Link>
            );
          })}
        </nav>

        {/* User Footer */}
        <div className="px-3 py-3 border-t border-slate-200">
          <div className="flex items-center space-x-3 px-3 py-2.5 rounded-xl bg-slate-50 border border-slate-200 mb-1.5">
            <div className="w-7 h-7 rounded-full bg-slate-900 flex items-center justify-center text-white font-bold text-xs flex-shrink-0">S</div>
            <div className="flex-1 min-w-0">
              <p className="text-slate-800 text-xs font-semibold truncate">Super Admin</p>
              <p className="text-slate-400 text-[10px] truncate">admin@clinix.cm</p>
            </div>
          </div>
          <button
            onClick={handleLogout}
            className="flex items-center space-x-3 text-red-500 hover:bg-red-50 w-full px-3 py-2 rounded-xl transition-all duration-200"
          >
            <LogOut size={15} />
            <span className="font-medium text-xs">Logout</span>
          </button>
        </div>
      </aside>

      {/* Main Content */}
      <main className="flex-1 flex flex-col overflow-hidden">
        {/* Top bar */}
        <header className="bg-white border-b border-slate-200 px-8 h-14 flex items-center justify-between flex-shrink-0">
          <div>
            <h2 className="font-bold text-slate-900 text-sm">
              {menuItems.find((m) => m.path === location.pathname)?.label ?? 'Dashboard'}
            </h2>
            <p className="text-slate-400 text-[11px]">Clinix Healthcare Management</p>
          </div>
          <div className="flex items-center space-x-2">
            <button className="relative w-8 h-8 rounded-lg border border-slate-200 bg-white flex items-center justify-center hover:bg-slate-50 transition-colors">
              <Bell size={14} className="text-slate-600" />
              <span className="absolute top-1 right-1 w-1.5 h-1.5 bg-orange-400 rounded-full"></span>
            </button>
            <div className="w-8 h-8 rounded-lg bg-slate-900 flex items-center justify-center text-white font-bold text-xs">
              S
            </div>
          </div>
        </header>

        <div className="flex-1 overflow-auto p-6">
          <Outlet />
        </div>
      </main>
    </div>
  );
};

export default Layout;
