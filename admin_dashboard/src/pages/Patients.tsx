import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Plus, Edit2, Trash2, UserPlus, Phone, Mail, Droplet } from 'lucide-react';

interface Patient {
  patient_id: string;
  first_name: string;
  last_name: string;
  phone_number: string;
  email: string;
  date_of_birth: string | null;
  gender: string | null;
  blood_type: string | null;
}

const fetchPatients = async (): Promise<Patient[]> => {
  const token = localStorage.getItem('clinix_admin_token');
  const res = await fetch('http://127.0.0.1:8000/api/v1/admin/patients/', {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  if (res.status === 401) {
    localStorage.removeItem('clinix_admin_token');
    window.location.href = '/login';
    return [];
  }
  if (!res.ok) throw new Error('Failed to fetch patients');
  return res.json();
};

const Patients = () => {
  const queryClient = useQueryClient();
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingPatient, setEditingPatient] = useState<Patient | null>(null);
  
  // Form state
  const [formData, setFormData] = useState({
    first_name: '',
    last_name: '',
    phone_number: '',
    email: '',
    date_of_birth: '',
    gender: 'other',
    blood_type: '',
  });

  const { data: patients, isLoading, isError, error } = useQuery<Patient[]>({
    queryKey: ['patients'],
    queryFn: fetchPatients,
  });

  const mutation = useMutation({
    mutationFn: async (formData: any) => {
      const token = localStorage.getItem('clinix_admin_token');
      const url = editingPatient 
          ? `http://127.0.0.1:8000/api/v1/admin/patients/${editingPatient.patient_id}/` 
          : 'http://127.0.0.1:8000/api/v1/admin/patients/';
      const method = editingPatient ? 'PUT' : 'POST';
      
      const payload = {
        ...formData,
        date_of_birth: formData.date_of_birth || null,
      };

      const res = await fetch(url, {
        method,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(payload)
      });
      if (!res.ok) {
        const errorData = await res.json().catch(() => null);
        throw new Error(errorData?.detail || errorData?.phone_number?.[0] || 'Failed to save patient');
      }
      return res.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['patients'] });
      setIsModalOpen(false);
      resetForm();
    },
    onError: (err: any) => {
      alert(`Error: ${err.message}`);
    }
  });

  const deleteMutation = useMutation({
    mutationFn: async (id: string) => {
      const token = localStorage.getItem('clinix_admin_token');
      const res = await fetch(`http://127.0.0.1:8000/api/v1/admin/patients/${id}/`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (!res.ok) throw new Error('Failed to delete patient');
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['patients'] });
    }
  });

  const handleAddSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    mutation.mutate(formData);
  };

  const handleEdit = (p: Patient) => {
    setEditingPatient(p);
    setFormData({
      first_name: p.first_name || '',
      last_name: p.last_name || '',
      phone_number: p.phone_number || '',
      email: p.email || '',
      date_of_birth: p.date_of_birth || '',
      gender: p.gender || 'other',
      blood_type: p.blood_type || '',
    });
    setIsModalOpen(true);
  };

  const handleDelete = (id: string) => {
    if (confirm('Are you sure you want to delete this patient?')) {
      deleteMutation.mutate(id);
    }
  };

  const resetForm = () => {
    setEditingPatient(null);
    setFormData({
      first_name: '', last_name: '', phone_number: '', email: '', date_of_birth: '', gender: 'other', blood_type: '',
    });
  };

  if (isLoading) return <div className="p-4 text-gray-500">Loading patients...</div>;
  if (isError) return <div className="p-4 text-red-500 font-bold">Error loading patients: {error?.message}</div>;

  return (
    <div className="animate-in fade-in duration-500">
      <div className="flex justify-between items-center mb-6">
        <div>
          <h2 className="text-2xl font-bold text-dark-900">Patients Directory</h2>
          <p className="text-sm text-gray-500 mt-1">Manage platform patients and demographic records</p>
        </div>
        <button 
          onClick={() => { resetForm(); setIsModalOpen(true); }}
          className="flex items-center space-x-2 bg-sky-500 text-white px-4 py-2.5 rounded-xl font-semibold shadow-lg shadow-sky-500/30 hover:bg-sky-600 transition hover:scale-[1.02] active:scale-95"
        >
          <UserPlus size={18} />
          <span>Add Patient</span>
        </button>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50/80">
            <tr>
              <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Patient Name</th>
              <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Contact</th>
              <th className="px-6 py-4 text-left text-xs font-bold text-gray-500 uppercase tracking-wider">Demographics</th>
              <th className="px-6 py-4 text-right text-xs font-bold text-gray-500 uppercase tracking-wider">Actions</th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-100">
            {patients?.map((pat) => (
              <tr key={pat.patient_id} className="hover:bg-sky-50/30 transition-colors group">
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="flex items-center space-x-3">
                    <div className="w-10 h-10 rounded-xl bg-sky-100 text-sky-600 flex items-center justify-center font-bold text-lg pointer-events-none">
                      {pat.first_name?.[0] || 'P'}
                    </div>
                    <div>
                      <p className="text-sm font-bold text-dark-900">{pat.first_name} {pat.last_name}</p>
                      <p className="text-xs text-gray-400 font-mono mt-0.5">{pat.patient_id.split('-')[0]}</p>
                    </div>
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="space-y-1">
                    <div className="flex items-center text-sm text-gray-600">
                      <Phone size={14} className="mr-2 text-gray-400" />
                      {pat.phone_number}
                    </div>
                    {pat.email && (
                      <div className="flex items-center text-xs text-gray-500">
                        <Mail size={14} className="mr-2 text-gray-400" />
                        {pat.email}
                      </div>
                    )}
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="flex items-center space-x-3 text-sm">
                    {pat.blood_type && (
                      <span className="flex items-center bg-red-50 text-red-600 px-2.5 py-1 rounded-lg text-xs font-bold border border-red-100">
                        <Droplet size={12} className="mr-1" />
                        {pat.blood_type}
                      </span>
                    )}
                    <span className="text-gray-500 capitalize">{pat.gender || 'Not specified'}</span>
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-right">
                  <div className="flex items-center justify-end space-x-2 opacity-0 group-hover:opacity-100 transition-opacity">
                    <button 
                      onClick={() => handleEdit(pat)}
                      className="p-2 text-sky-500 hover:bg-sky-50 rounded-xl transition"
                      title="Edit Patient"
                    >
                      <Edit2 size={16} />
                    </button>
                    <button 
                      onClick={() => handleDelete(pat.patient_id)}
                      className="p-2 text-red-500 hover:bg-red-50 rounded-xl transition"
                      title="Delete Patient"
                    >
                      <Trash2 size={16} />
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        
        {patients?.length === 0 && (
          <div className="p-16 text-center">
            <div className="w-16 h-16 bg-gray-50 rounded-full flex items-center justify-center mx-auto mb-4">
              <UserPlus size={24} className="text-gray-400" />
            </div>
            <h3 className="text-lg font-bold text-dark-900 mb-1">No patients found</h3>
            <p className="text-sm text-gray-500">Get started by adding a new patient to the system.</p>
          </div>
        )}
      </div>

      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-dark-900/40 backdrop-blur-sm animate-in fade-in">
          <div className="bg-white rounded-3xl w-full max-w-lg shadow-2xl overflow-hidden animate-in zoom-in-95 duration-200">
            <div className="px-6 py-5 border-b border-gray-100 flex justify-between items-center bg-gray-50/50">
              <h3 className="text-lg font-bold text-dark-900">{editingPatient ? 'Edit Patient' : 'Add New Patient'}</h3>
              <button 
                onClick={() => setIsModalOpen(false)}
                className="text-gray-400 hover:bg-gray-200 p-2 rounded-full transition"
              >
                <Plus size={20} className="rotate-45" />
              </button>
            </div>
            <form onSubmit={handleAddSubmit} className="p-6 space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-bold text-gray-500 mb-1">First Name</label>
                  <input required type="text" className="w-full px-4 py-2.5 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-sky-500 outline-none transition" 
                    value={formData.first_name} onChange={e => setFormData({...formData, first_name: e.target.value})} />
                </div>
                <div>
                  <label className="block text-xs font-bold text-gray-500 mb-1">Last Name</label>
                  <input required type="text" className="w-full px-4 py-2.5 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-sky-500 outline-none transition" 
                    value={formData.last_name} onChange={e => setFormData({...formData, last_name: e.target.value})} />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                 <div>
                  <label className="block text-xs font-bold text-gray-500 mb-1">Phone Number</label>
                  <input required type="tel" className="w-full px-4 py-2.5 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-sky-500 outline-none transition" 
                    value={formData.phone_number} onChange={e => setFormData({...formData, phone_number: e.target.value})} placeholder="+237..." />
                </div>
                <div>
                  <label className="block text-xs font-bold text-gray-500 mb-1">Email Address</label>
                  <input type="email" className="w-full px-4 py-2.5 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-sky-500 outline-none transition" 
                    value={formData.email} onChange={e => setFormData({...formData, email: e.target.value})} />
                </div>
              </div>

              <div className="grid grid-cols-3 gap-4">
                <div className="col-span-1">
                  <label className="block text-xs font-bold text-gray-500 mb-1">Gender</label>
                  <select className="w-full px-4 py-2.5 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-sky-500 outline-none transition capitalize"
                    value={formData.gender} onChange={e => setFormData({...formData, gender: e.target.value})}>
                    <option value="male">Male</option>
                    <option value="female">Female</option>
                    <option value="other">Other</option>
                  </select>
                </div>
                <div className="col-span-1">
                  <label className="block text-xs font-bold text-gray-500 mb-1">Blood Type</label>
                  <input type="text" className="w-full px-4 py-2.5 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-sky-500 outline-none transition" 
                    value={formData.blood_type} onChange={e => setFormData({...formData, blood_type: e.target.value})} placeholder="e.g. O+" />
                </div>
                <div className="col-span-1">
                  <label className="block text-xs font-bold text-gray-500 mb-1">Date of Birth</label>
                  <input type="date" className="w-full px-4 py-2.5 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-sky-500 outline-none transition" 
                    value={formData.date_of_birth} onChange={e => setFormData({...formData, date_of_birth: e.target.value})} />
                </div>
              </div>

              <div className="flex space-x-3 pt-4 mt-6 border-t border-gray-100">
                <button type="button" onClick={() => setIsModalOpen(false)} className="flex-1 px-4 py-2.5 bg-gray-100 text-gray-600 font-bold rounded-xl hover:bg-gray-200 transition">Cancel</button>
                <button type="submit" disabled={mutation.isPending} className="flex-1 px-4 py-2.5 bg-sky-500 text-white font-bold rounded-xl shadow-lg shadow-sky-500/30 hover:bg-sky-600 transition disabled:opacity-50">
                  {mutation.isPending ? 'Saving...' : 'Save Patient'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default Patients;
