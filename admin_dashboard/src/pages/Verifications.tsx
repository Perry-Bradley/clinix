import { useState, useEffect } from 'react';
import { useQuery } from '@tanstack/react-query';
import { AlertTriangle, Check, Eye, RefreshCw, Search, ShieldCheck } from 'lucide-react';
import DocumentReviewModal from '../components/DocumentReviewModal';
import { API_BASE } from '../config';

interface VerificationRequest {
  id: string;
  name: string;
  spec: string;
  submitted: string;
  license: string;
  documents?: { type: 'image' | 'video'; url: string; label: string }[];
}

interface CMCDoctor {
  name: string;
  specialization: string;
  region: string;
  registration_number: string;
}

interface CMCResponse {
  count: number;
  total_scraped: number;
  pages_scraped: number;
  fetched_at: number;
  source: string;
  scrape_error: string | null;
  scraping?: boolean;
  results: CMCDoctor[];
}

const authHeader = () => ({ Authorization: `Bearer ${localStorage.getItem('clinix_admin_token')}` });

const fetchVerifications = async (): Promise<VerificationRequest[]> => {
  const res = await fetch(`${API_BASE}/admin/verifications/`, { headers: authHeader() });
  if (res.status === 401) { localStorage.removeItem('clinix_admin_token'); window.location.href = '/login'; return []; }
  if (!res.ok) throw new Error('Failed to fetch');
  const data = await res.json();
  return data.map((item: any) => ({
    id: item.provider_id,
    name: item.name,
    spec: item.specialization,
    submitted: new Date(item.submitted_at).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }),
    license: item.license_number,
    documents: [],
  }));
};

const fetchCMCDoctors = async (search = '', refresh = false): Promise<CMCResponse> => {
  const params = new URLSearchParams();
  if (search) params.set('search', search);
  if (refresh) params.set('refresh', '1');
  const res = await fetch(`${API_BASE}/admin/cmc-doctors/?${params}`, { headers: authHeader() });
  if (!res.ok) throw new Error('Failed to fetch CMC data');
  return res.json();
};

const Verifications = () => {
  const [activeTab, setActiveTab] = useState<'verifications' | 'cmc'>('verifications');
  const [selectedRequest, setSelectedRequest] = useState<VerificationRequest | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [cmcSearch, setCmcSearch] = useState('');
  const [cmcRefresh, setCmcRefresh] = useState(false);

  const { data: requests, isLoading: verLoading, refetch } = useQuery<VerificationRequest[]>({
    queryKey: ['verifications'],
    queryFn: fetchVerifications,
    enabled: activeTab === 'verifications',
  });

  const { data: cmcData, isLoading: cmcLoading, refetch: refetchCMC } = useQuery({
    queryKey: ['cmc-doctors', cmcSearch, cmcRefresh],
    queryFn: () => fetchCMCDoctors(cmcSearch, cmcRefresh),
    enabled: activeTab === 'cmc',
  });

  // The scrape now runs in the background on the server; while it's running,
  // poll every 25s so the list appears automatically once it's stored.
  useEffect(() => {
    if (activeTab === 'cmc' && cmcData?.scraping) {
      const t = setTimeout(() => refetchCMC(), 25000);
      return () => clearTimeout(t);
    }
  }, [activeTab, cmcData?.scraping, cmcData?.count, refetchCMC]);

  const handleReview = async (req: VerificationRequest) => {
    try {
      const res = await fetch(`${API_BASE}/admin/verifications/${req.id}/`, { headers: authHeader() });
      if (!res.ok) throw new Error('Failed to fetch verification details');
      const detail = await res.json();
      setSelectedRequest({ ...req, spec: detail.spec || req.spec, license: detail.license || req.license, documents: detail.documents || [] });
      setIsModalOpen(true);
    } catch { alert('Could not load verification documents'); }
  };

  const updateStatus = async (status: 'approved' | 'rejected') => {
    if (!selectedRequest) return;
    const res = await fetch(`${API_BASE}/admin/verifications/${selectedRequest.id}/`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', ...authHeader() },
      body: JSON.stringify({ status }),
    });
    if (res.ok) { alert(`${selectedRequest.name} has been ${status}!`); setIsModalOpen(false); refetch(); }
    else alert('Failed to update status');
  };

  return (
    <div>
      {/* Page header */}
      <div className="flex items-center justify-between mb-5">
        <h2 className="text-xl font-bold text-slate-900">Verifications</h2>
        {activeTab === 'verifications' && (
          <span className="bg-orange-100 text-orange-700 text-xs font-semibold px-3 py-1 rounded-full">
            {requests?.length ?? 0} Pending
          </span>
        )}
      </div>

      {/* Tabs */}
      <div className="flex space-x-1 mb-5 border-b border-slate-200">
        <button
          onClick={() => setActiveTab('verifications')}
          className={`px-4 py-2.5 text-sm font-semibold border-b-2 transition-colors ${
            activeTab === 'verifications'
              ? 'border-slate-900 text-slate-900'
              : 'border-transparent text-slate-500 hover:text-slate-700'
          }`}
        >
          Provider Verifications
        </button>
        <button
          onClick={() => setActiveTab('cmc')}
          className={`flex items-center space-x-1.5 px-4 py-2.5 text-sm font-semibold border-b-2 transition-colors ${
            activeTab === 'cmc'
              ? 'border-slate-900 text-slate-900'
              : 'border-transparent text-slate-500 hover:text-slate-700'
          }`}
        >
          <ShieldCheck size={14} />
          <span>Cameroon Medical Council</span>
        </button>
      </div>

      {/* Tab: Provider Verifications */}
      {activeTab === 'verifications' && (
        verLoading ? (
          <div className="p-4 text-slate-400 text-sm">Loading verifications...</div>
        ) : (
          <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
            <table className="min-w-full divide-y divide-slate-100">
              <thead className="bg-slate-50">
                <tr>
                  {['Provider Name', 'Specialization', 'License No.', 'Submitted', 'Actions'].map((col) => (
                    <th key={col} className="px-5 py-3 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                      {col}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-slate-100">
                {requests?.map((req) => (
                  <tr key={req.id} className="hover:bg-slate-50 transition">
                    <td className="px-5 py-3.5 whitespace-nowrap">
                      <div className="flex items-center space-x-3">
                        <div className="w-7 h-7 rounded-full bg-slate-900 flex items-center justify-center text-white text-xs font-semibold">
                          {req.name[0]}
                        </div>
                        <span className="text-sm font-medium text-slate-900">{req.name}</span>
                      </div>
                    </td>
                    <td className="px-5 py-3.5 whitespace-nowrap text-sm text-slate-500">{req.spec}</td>
                    <td className="px-5 py-3.5 whitespace-nowrap">
                      <span className="text-xs font-mono bg-slate-100 px-2 py-1 rounded border border-slate-200 text-slate-600">{req.license}</span>
                    </td>
                    <td className="px-5 py-3.5 whitespace-nowrap text-sm text-slate-500">{req.submitted}</td>
                    <td className="px-5 py-3.5 whitespace-nowrap">
                      <div className="flex items-center space-x-2">
                        <button onClick={() => handleReview(req)} className="flex items-center space-x-1 px-3 py-1.5 bg-slate-50 text-slate-600 hover:bg-slate-100 rounded-lg transition text-xs font-semibold border border-slate-200">
                          <Eye size={12} /><span>Review</span>
                        </button>
                        <button onClick={() => { setSelectedRequest(req); updateStatus('approved'); }} className="flex items-center space-x-1 px-3 py-1.5 bg-emerald-50 text-emerald-700 hover:bg-emerald-600 hover:text-white rounded-lg transition text-xs font-semibold border border-emerald-200">
                          <Check size={12} /><span>Approve</span>
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {requests?.length === 0 && (
              <div className="p-12 text-center text-slate-400">
                <p className="text-sm">No pending verifications at this time.</p>
              </div>
            )}
          </div>
        )
      )}

      {/* Tab: Cameroon Medical Council */}
      {activeTab === 'cmc' && (
        <div>
          <div className="flex items-center justify-between mb-4">
            <div>
              <p className="text-sm text-slate-500">
                Records scraped from the{' '}
                <a href="https://www.ordremedecinsducameroun.org" target="_blank" rel="noreferrer" className="text-slate-700 underline font-medium">
                  Ordre des Médecins du Cameroun
                </a>
              </p>
              {cmcData?.fetched_at && (
                <p className="text-xs text-slate-400 mt-0.5">
                  Last synced: {new Date(cmcData.fetched_at * 1000).toLocaleString()}
                  {cmcData.pages_scraped > 0 && ` · ${cmcData.pages_scraped} page${cmcData.pages_scraped !== 1 ? 's' : ''} scraped`}
                  {cmcData.total_scraped > 0 && ` · ${cmcData.total_scraped} total records`}
                </p>
              )}
            </div>
            <button
              onClick={() => { setCmcRefresh(true); setTimeout(() => setCmcRefresh(false), 500); refetchCMC(); }}
              className="flex items-center space-x-1.5 px-3 py-2 bg-slate-900 text-white rounded-lg text-xs font-semibold hover:bg-slate-700 transition"
            >
              <RefreshCw size={12} className={cmcLoading ? 'animate-spin' : ''} />
              <span>Refresh</span>
            </button>
          </div>

          {/* Scrape error banner */}
          {cmcData?.scrape_error && (
            <div className="flex items-start space-x-3 bg-amber-50 border border-amber-200 rounded-xl px-4 py-3 mb-4">
              <AlertTriangle size={16} className="text-amber-500 mt-0.5 shrink-0" />
              <div>
                <p className="text-xs font-semibold text-amber-800">Scrape notice</p>
                <p className="text-xs text-amber-700 mt-0.5">{cmcData.scrape_error}</p>
              </div>
            </div>
          )}

          {/* Search */}
          <div className="relative mb-4">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input
              type="text"
              placeholder="Search by name, specialization, region, or reg. no..."
              value={cmcSearch}
              onChange={e => setCmcSearch(e.target.value)}
              className="w-full pl-9 pr-4 py-2 text-sm border border-slate-200 rounded-xl bg-white focus:outline-none focus:ring-2 focus:ring-slate-900/10"
            />
          </div>

          {cmcLoading ? (
            <div className="p-8 text-center text-slate-400 text-sm">
              <RefreshCw size={20} className="animate-spin mx-auto mb-2 text-slate-300" />
              Scraping CMC directory — this may take a few seconds...
            </div>
          ) : (
            <>
              {cmcData && cmcData.count > 0 ? (
                <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
                  <div className="px-5 py-3 border-b border-slate-100 bg-slate-50 flex items-center justify-between">
                    <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">
                      {cmcSearch
                        ? `${cmcData.count} result${cmcData.count !== 1 ? 's' : ''} for "${cmcSearch}"`
                        : `${cmcData.count} doctor${cmcData.count !== 1 ? 's' : ''}`}
                    </span>
                    {cmcSearch && cmcData.total_scraped > 0 && (
                      <span className="text-xs text-slate-400">{cmcData.total_scraped} total in directory</span>
                    )}
                  </div>
                  <table className="min-w-full divide-y divide-slate-100">
                    <thead className="bg-slate-50">
                      <tr>
                        {['Name', 'Specialization', 'Region', 'Registration No.'].map(col => (
                          <th key={col} className="px-5 py-3 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">{col}</th>
                        ))}
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100">
                      {cmcData.results.map((doc, i) => (
                        <tr key={i} className="hover:bg-slate-50 transition">
                          <td className="px-5 py-3 whitespace-nowrap">
                            <div className="flex items-center space-x-3">
                              <div className="w-7 h-7 rounded-full bg-slate-900 flex items-center justify-center text-white text-xs font-semibold">
                                {doc.name?.[0]?.toUpperCase() ?? 'D'}
                              </div>
                              <span className="text-sm font-medium text-slate-900">{doc.name}</span>
                            </div>
                          </td>
                          <td className="px-5 py-3 text-sm text-slate-500">{doc.specialization || '—'}</td>
                          <td className="px-5 py-3 text-sm text-slate-500">{doc.region || '—'}</td>
                          <td className="px-5 py-3">
                            {doc.registration_number
                              ? <span className="text-xs font-mono bg-slate-100 px-2 py-1 rounded border border-slate-200 text-slate-600">{doc.registration_number}</span>
                              : <span className="text-slate-300">—</span>}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              ) : cmcData?.scraping ? (
                <div className="bg-white rounded-xl border border-slate-200 p-12 text-center">
                  <RefreshCw size={24} className="animate-spin mx-auto mb-3 text-slate-300" />
                  <p className="text-sm font-medium text-slate-600">Scraping the directory in the background…</p>
                  <p className="text-xs text-slate-400 mt-1 max-w-sm mx-auto">
                    This takes about a minute (≈64 pages). The list will appear here automatically — no need to wait on this screen.
                  </p>
                </div>
              ) : (
                <div className="bg-white rounded-xl border border-slate-200 p-12 text-center">
                  <ShieldCheck size={32} className="mx-auto mb-3 text-slate-300" />
                  <p className="text-sm font-medium text-slate-600">
                    {cmcSearch ? `No results for "${cmcSearch}"` : 'No records yet'}
                  </p>
                  <p className="text-xs text-slate-400 mt-1 max-w-sm mx-auto">
                    {cmcData?.scrape_error
                      ? 'See the notice above — the site may render its directory with JavaScript which cannot be scraped with a standard HTTP request.'
                      : 'Hit Refresh to scrape the directory. It runs in the background and the list refreshes automatically when done.'}
                  </p>
                  <a
                    href="https://www.ordremedecinsducameroun.org/annuaire"
                    target="_blank"
                    rel="noreferrer"
                    className="inline-block mt-4 text-xs font-semibold text-slate-700 underline"
                  >
                    Open CMC directory in browser →
                  </a>
                </div>
              )}
            </>
          )}
        </div>
      )}

      <DocumentReviewModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        providerName={selectedRequest?.name || ''}
        documents={selectedRequest?.documents || []}
        onApprove={() => updateStatus('approved')}
        onReject={() => updateStatus('rejected')}
      />
    </div>
  );
};

export default Verifications;
