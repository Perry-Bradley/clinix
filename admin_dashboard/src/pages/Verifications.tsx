import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Check, X, Eye } from 'lucide-react';
import DocumentReviewModal from '../components/DocumentReviewModal';

interface VerificationRequest {
  id: string;
  name: string;
  spec: string;
  submitted: string;
  license: string;
  documents?: { type: 'image' | 'video'; url: string; label: string }[];
}

const fetchVerifications = async (): Promise<VerificationRequest[]> => {
  const token = localStorage.getItem('clinix_admin_token');
  try {
    const res = await fetch('http://127.0.0.1:8000/api/v1/admin/verifications/', {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });
    if (res.status === 401) {
      localStorage.removeItem('clinix_admin_token');
      window.location.href = '/login';
      return [];
    }
    if (!res.ok) throw new Error('Failed to fetch');
    const data = await res.json();
    return data.map((item: any) => ({
      id: item.provider_id,
      name: item.name,
      spec: item.specialization,
      submitted: new Date(item.submitted_at).toLocaleDateString(),
      license: item.license_number,
      // Will fetch documents on review if needed, but for now we put empty or placeholder
      documents: []
    }));
  } catch (error) {
    console.error(error);
    return [];
  }
};

const Verifications = () => {
  const [selectedRequest, setSelectedRequest] = useState<VerificationRequest | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);

  const { data: requests, isLoading, refetch } = useQuery<VerificationRequest[]>({
    queryKey: ['verifications'],
    queryFn: fetchVerifications,
  });

  const handleReview = async (req: VerificationRequest) => {
    const token = localStorage.getItem('clinix_admin_token');
    try {
      const res = await fetch(`http://127.0.0.1:8000/api/v1/admin/verifications/${req.id}/`, {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      });
      if (!res.ok) throw new Error('Failed to fetch verification details');
      const detail = await res.json();
      setSelectedRequest({
        ...req,
        spec: detail.spec || req.spec,
        license: detail.license || req.license,
        documents: detail.documents || [],
      });
      setIsModalOpen(true);
    } catch (err) {
      console.error(err);
      alert('Could not load verification documents');
    }
  };

  const updateStatus = async (status: 'approved' | 'rejected') => {
    if (!selectedRequest) return;
    const token = localStorage.getItem('clinix_admin_token');
    try {
      const res = await fetch(`http://127.0.0.1:8000/api/v1/admin/verifications/${selectedRequest.id}/`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ status })
      });
      if (res.ok) {
        alert(`${selectedRequest.name} has been ${status}!`);
        setIsModalOpen(false);
        refetch();
      } else {
        alert('Failed to update status');
      }
    } catch(err) {
      console.error(err);
      alert('Error updating status');
    }
  };

  const handleApprove = () => updateStatus('approved');
  const handleReject = () => updateStatus('rejected');

  if (isLoading) return <div className="p-4 text-gray-500">Loading verifications...</div>;

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-2xl font-bold">Provider Verifications</h2>
        <span className="bg-orange-100 text-orange-700 text-sm font-semibold px-3 py-1 rounded-full">
          {requests?.length} Pending
        </span>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              {['Provider Name', 'Specialization', 'License No.', 'Submitted', 'Actions'].map((col) => (
                <th
                  key={col}
                  className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                >
                  {col}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {requests?.map((req: VerificationRequest) => (
              <tr key={req.id} className="hover:bg-gray-50 transition">
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="flex items-center space-x-3">
                    <div className="w-8 h-8 rounded-full bg-teal-600 flex items-center justify-center text-white text-sm font-semibold shadow-sm shadow-teal-600/20">
                      {req.name.split(' ')[1]?.[0] || req.name[0]}
                    </div>
                    <span className="text-sm font-medium text-gray-900">{req.name}</span>
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{req.spec}</td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className="text-xs font-mono bg-gray-100 px-2 py-1 rounded text-gray-600 border border-gray-200">{req.license}</span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{req.submitted}</td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="flex items-center space-x-2">
                    <button 
                      onClick={() => handleReview(req)}
                      className="flex items-center space-x-1 px-3 py-1.5 bg-gray-50 text-gray-600 hover:bg-gray-100 hover:text-dark-900 rounded-lg transition text-xs font-bold border border-gray-100"
                    >
                      <Eye size={13} />
                      <span>Review</span>
                    </button>
                    <button 
                      onClick={() => { setSelectedRequest(req); handleApprove(); }}
                      className="flex items-center space-x-1 px-3 py-1.5 bg-teal-50 text-teal-600 hover:bg-teal-600 hover:text-white rounded-lg transition text-xs font-bold border border-teal-100"
                    >
                      <Check size={13} />
                      <span>Approve</span>
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        {requests?.length === 0 && (
          <div className="p-12 text-center text-gray-400">
            <UserCheck className="mx-auto mb-3 opacity-40" size={40} />
            <p>No pending verifications at this time.</p>
          </div>
        )}
      </div>

      <DocumentReviewModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        providerName={selectedRequest?.name || ''}
        documents={selectedRequest?.documents || []}
        onApprove={handleApprove}
        onReject={handleReject}
      />
    </div>
  );
};

// local helper for empty state
const UserCheck = ({ size, className }: { size: number; className?: string }) => (
  <svg className={className} width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
    <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" />
    <polyline points="16 11 18 13 22 9" />
  </svg>
);

export default Verifications;
