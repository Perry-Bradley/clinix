import { Outlet, Link, useNavigate, useLocation } from 'react-router-dom';
import { LayoutDashboard, Users, UserCheck, LogOut, Bell, Settings } from 'lucide-react';

const Layout = () => {
  const navigate = useNavigate();
  const location = useLocation();

  const handleLogout = () => {
    localStorage.removeItem('clinix_admin_token');
    navigate('/login');
  };

  const menuItems = [
    { path: '/', icon: <LayoutDashboard size={18} />, label: 'Dashboard' },
    { path: '/users', icon: <Users size={18} />, label: 'Users' },
    { path: '/verifications', icon: <UserCheck size={18} />, label: 'Verifications' },
  ];

  return (
    <div className="flex h-screen bg-slate-100 overflow-hidden">
      {/* Sidebar */}
      <aside className="w-64 bg-dark-900 flex flex-col shadow-2xl">
        {/* Logo */}
        <div className="px-6 py-6 border-b border-white/10">
          <div className="flex items-center space-x-3">
            <div className="w-9 h-9 rounded-xl bg-sky-500 flex items-center justify-center shadow-lg shadow-sky-500/40">
              <span className="text-white text-lg">🏥</span>
            </div>
            <div>
              <h1 className="text-white font-bold text-lg tracking-tight leading-none">Clinix</h1>
              <p className="text-sky-400 text-xs font-medium">Admin Portal</p>
            </div>
          </div>
        </div>

        {/* Nav */}
        <nav className="flex-1 px-4 py-6 space-y-1">
          <p className="text-sky-400/60 text-[10px] font-semibold uppercase tracking-widest px-4 mb-3">Main Menu</p>
          {menuItems.map((item) => {
            const isActive = location.pathname === item.path;
            return (
              <Link key={item.path} to={item.path} className={isActive ? 'sidebar-link-active' : 'sidebar-link'}>
                {item.icon}
                <span className="font-medium text-sm">{item.label}</span>
              </Link>
            );
          })}

          <div className="pt-6">
            <p className="text-sky-400/60 text-[10px] font-semibold uppercase tracking-widest px-4 mb-3">System</p>
            <button className="sidebar-link w-full text-left">
              <Settings size={18} />
              <span className="font-medium text-sm">Settings</span>
            </button>
          </div>
        </nav>

        {/* User Footer */}
        <div className="px-4 py-4 border-t border-white/10">
          <div className="flex items-center space-x-3 px-4 py-3 rounded-xl bg-white/5 mb-2">
            <div className="w-8 h-8 rounded-full bg-sky-500 flex items-center justify-center text-white font-bold text-sm">S</div>
            <div className="flex-1 min-w-0">
              <p className="text-white text-sm font-semibold truncate">Super Admin</p>
              <p className="text-sky-400 text-xs truncate">admin@clinix.cm</p>
            </div>
          </div>
          <button
            onClick={handleLogout}
            className="flex items-center space-x-3 text-red-400 hover:bg-red-500/10 w-full px-4 py-2.5 rounded-xl transition-all duration-200"
          >
            <LogOut size={16} />
            <span className="font-medium text-sm">Logout</span>
          </button>
        </div>
      </aside>

      {/* Main Content */}
      <main className="flex-1 flex flex-col overflow-hidden">
        {/* Top bar */}
        <header className="bg-white border-b border-gray-200 px-8 h-16 flex items-center justify-between shadow-sm flex-shrink-0">
          <div>
            <h2 className="font-bold text-dark-900 text-base capitalize">
              {location.pathname === '/' ? 'Dashboard' : location.pathname.replace('/', '')}
            </h2>
            <p className="text-gray-400 text-xs">Clinix Healthcare Management</p>
          </div>
          <div className="flex items-center space-x-3">
            <button className="relative w-9 h-9 rounded-full bg-dark-900 flex items-center justify-center hover:bg-dark-700 transition-colors">
              <Bell size={16} className="text-sky-400" />
              <span className="absolute top-1.5 right-1.5 w-2 h-2 bg-orange-400 rounded-full ring-2 ring-white"></span>
            </button>
            <div className="w-9 h-9 rounded-full bg-sky-500 flex items-center justify-center text-white font-bold text-sm shadow-lg shadow-sky-500/30">
              S
            </div>
          </div>
        </header>

        <div className="flex-1 overflow-auto p-8">
          <Outlet />
        </div>
      </main>
    </div>
  );
};

export default Layout;
