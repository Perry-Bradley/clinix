import { Routes, Route, Navigate } from 'react-router-dom';
import Layout from './components/Layout';
import Dashboard from './pages/Dashboard';
import Login from './pages/Login';
import Users from './pages/Users';
import Verifications from './pages/Verifications';
import Patients from './pages/Patients';
import Revenue from './pages/Revenue';
import LabTests from './pages/LabTests';
import Specialties from './pages/Specialties';
import Facilities from './pages/Facilities';
import Appointments from './pages/Appointments';

// A token is only good if it exists AND hasn't expired — otherwise every
// page silently renders empty data until the admin logs out manually.
const isAuthenticated = () => {
    const token = localStorage.getItem('clinix_admin_token');
    if (!token) return false;
    try {
        const { exp } = JSON.parse(atob(token.split('.')[1]));
        if (typeof exp === 'number' && exp * 1000 < Date.now()) {
            localStorage.removeItem('clinix_admin_token');
            return false;
        }
    } catch {
        return false;
    }
    return true;
};

const ProtectedRoute = ({ children }: { children: React.ReactNode }) => {
    if (!isAuthenticated()) {
        return <Navigate to="/login" replace />;
    }
    return <>{children}</>;
};

function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route path="/" element={
          <ProtectedRoute>
              <Layout />
          </ProtectedRoute>
      }>
        <Route index element={<Dashboard />} />
        <Route path="users" element={<Users />} />
        <Route path="patients" element={<Patients />} />
        <Route path="verifications" element={<Verifications />} />
        <Route path="appointments" element={<Appointments />} />
        <Route path="revenue" element={<Revenue />} />
        <Route path="lab-tests" element={<LabTests />} />
        <Route path="specialties" element={<Specialties />} />
        <Route path="facilities" element={<Facilities />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

export default App;
