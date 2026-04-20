import { Routes, Route, Navigate } from 'react-router-dom';
import Layout from './components/Layout';
import Dashboard from './pages/Dashboard';
import Login from './pages/Login';
import Users from './pages/Users';
import Verifications from './pages/Verifications';
import Patients from './pages/Patients';
import Revenue from './pages/Revenue';
import LabTests from './pages/LabTests';

// Mock authentication check
const isAuthenticated = () => {
    return !!localStorage.getItem('clinix_admin_token');
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
        <Route path="revenue" element={<Revenue />} />
        <Route path="lab-tests" element={<LabTests />} />
      </Route>
    </Routes>
  );
}

export default App;
