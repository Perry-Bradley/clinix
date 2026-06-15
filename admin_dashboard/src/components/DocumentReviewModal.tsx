import React from 'react';
import Modal from './Modal';
import { ExternalLink, FileText, Video, CheckCircle, AlertCircle, Sparkles, Loader2, BadgeCheck, ShieldAlert, XOctagon, Check, X, Minus } from 'lucide-react';

interface Document {
  type: string;
  url: string;
  label: string;
}

export interface AIVerificationCheck {
  label: string;
  status: 'pass' | 'fail' | 'unknown';
  detail?: string;
}

export interface AIVerificationDoc {
  document_type: string;
  label: string;
  fields: Record<string, string>;
}

export interface AIVerification {
  match_percent: number;
  decision: 'approve' | 'review' | 'reject';
  summary: string;
  matched_registry_entry: { name: string; registration_number: string; specialization?: string } | null;
  signals: { name_similarity: number; reg_number_exact: boolean; reg_number_digits_match: boolean };
  candidates_checked: number;
  model: string;
  checks?: AIVerificationCheck[];
  documents?: AIVerificationDoc[];
  checks_passed?: number;
  checks_failed?: number;
  overall_decision?: 'approve' | 'review' | 'reject';
  overall_summary?: string;
}

const CHECK_ICON: Record<string, React.ReactNode> = {
  pass: <Check size={14} className="text-emerald-600" />,
  fail: <X size={14} className="text-red-600" />,
  unknown: <Minus size={14} className="text-slate-400" />,
};

interface DocumentReviewModalProps {
  isOpen: boolean;
  onClose: () => void;
  providerName: string;
  documents: Document[];
  onApprove: () => void;
  onReject: () => void;
  ai?: AIVerification | null;
  aiLoading?: boolean;
}

const DECISION_STYLES: Record<string, { ring: string; bar: string; chip: string; icon: React.ReactNode; label: string }> = {
  approve: { ring: 'border-emerald-200 bg-emerald-50', bar: 'bg-emerald-500', chip: 'bg-emerald-100 text-emerald-700', icon: <BadgeCheck size={16} />, label: 'Likely genuine — safe to approve' },
  review: { ring: 'border-amber-200 bg-amber-50', bar: 'bg-amber-500', chip: 'bg-amber-100 text-amber-700', icon: <ShieldAlert size={16} />, label: 'Uncertain — manual review advised' },
  reject: { ring: 'border-red-200 bg-red-50', bar: 'bg-red-500', chip: 'bg-red-100 text-red-700', icon: <XOctagon size={16} />, label: 'No registry match — likely reject' },
};

const DocumentReviewModal: React.FC<DocumentReviewModalProps> = ({
  isOpen,
  onClose,
  providerName,
  documents,
  onApprove,
  onReject,
  ai,
  aiLoading,
}) => {
  const effDecision = ai ? (ai.overall_decision ?? ai.decision) : null;
  const decision = effDecision ? DECISION_STYLES[effDecision] ?? DECISION_STYLES.review : null;
  return (
    <Modal isOpen={isOpen} onClose={onClose} title={`Review Documents: ${providerName}`} maxWidth="max-w-4xl">
      <div className="space-y-8">
        {/* AI verification — autonomous CMC registry match */}
        <div className={`rounded-2xl border p-5 ${decision ? decision.ring : 'border-slate-200 bg-slate-50'}`}>
          <div className="flex items-center space-x-2 mb-3">
            <Sparkles size={16} className="text-indigo-600" />
            <h4 className="text-sm font-bold text-slate-800">AI Verification</h4>
            <span className="text-[10px] font-semibold uppercase tracking-wider text-slate-400">CMC registry match</span>
          </div>

          {aiLoading ? (
            <div className="flex items-center space-x-2 text-sm text-slate-500 py-2">
              <Loader2 size={16} className="animate-spin" />
              <span>Matching signup details against the Cameroon Medical Council registry…</span>
            </div>
          ) : ai ? (
            <div className="space-y-4">
              <div className="flex items-center space-x-4">
                {/* Big probability */}
                <div className="flex-shrink-0">
                  <div className="text-3xl font-extrabold text-slate-900 leading-none">{ai.match_percent}%</div>
                  <div className="text-[11px] text-slate-500 mt-1">match probability</div>
                </div>
                {/* Bar + decision */}
                <div className="flex-1">
                  <div className="h-2.5 w-full rounded-full bg-white/70 overflow-hidden border border-black/5">
                    <div className={`h-full ${decision?.bar}`} style={{ width: `${Math.max(2, Math.min(100, ai.match_percent))}%` }} />
                  </div>
                  <div className="mt-2 flex items-center space-x-2">
                    <span className={`inline-flex items-center space-x-1 px-2 py-0.5 rounded-full text-[11px] font-bold ${decision?.chip}`}>
                      {decision?.icon}<span className="uppercase">{effDecision}</span>
                    </span>
                    <span className="text-xs text-slate-600">{decision?.label}</span>
                  </div>
                </div>
              </div>

              {/* Matched entry + signals */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
                <div className="bg-white/70 rounded-xl border border-black/5 p-3">
                  <p className="font-semibold text-slate-500 mb-1">Closest registry record</p>
                  {ai.matched_registry_entry ? (
                    <>
                      <p className="font-semibold text-slate-800">{ai.matched_registry_entry.name}</p>
                      <p className="text-slate-500">Reg. {ai.matched_registry_entry.registration_number || '—'}{ai.matched_registry_entry.specialization ? ` · ${ai.matched_registry_entry.specialization}` : ''}</p>
                    </>
                  ) : (
                    <p className="text-slate-400">No candidate found in the registry.</p>
                  )}
                </div>
                <div className="bg-white/70 rounded-xl border border-black/5 p-3 space-y-1">
                  <p className="font-semibold text-slate-500 mb-1">Signals</p>
                  <div className="flex justify-between"><span className="text-slate-500">Name similarity</span><span className="font-semibold text-slate-800">{Math.round(ai.signals.name_similarity * 100)}%</span></div>
                  <div className="flex justify-between"><span className="text-slate-500">License number match</span><span className="font-semibold text-slate-800">{ai.signals.reg_number_exact ? 'Exact' : ai.signals.reg_number_digits_match ? 'Partial' : 'None'}</span></div>
                </div>
              </div>
              {/* Document cross-checks — extracted from the uploaded ID + license */}
              {ai.checks && ai.checks.length > 0 && (
                <div className="bg-white/70 rounded-xl border border-black/5 p-3">
                  <p className="font-semibold text-slate-500 text-xs mb-2">Document cross-checks (read by AI from the uploads)</p>
                  <ul className="space-y-1.5">
                    {ai.checks.map((c, i) => (
                      <li key={i} className="flex items-start space-x-2 text-xs">
                        <span className="mt-0.5 flex-shrink-0">{CHECK_ICON[c.status]}</span>
                        <span className="text-slate-700 font-medium">{c.label}</span>
                        {c.detail && <span className="text-slate-400">— {c.detail}</span>}
                      </li>
                    ))}
                  </ul>
                  {ai.overall_summary && (
                    <p className="mt-2 pt-2 border-t border-black/5 text-[11px] text-slate-600 font-medium">{ai.overall_summary}</p>
                  )}
                </div>
              )}

              <p className="text-[10px] text-slate-400">
                Registry match {ai.match_percent}% · {ai.candidates_checked} records compared · model: {ai.model}
                {typeof ai.checks_passed === 'number' && ` · ${ai.checks_passed} checks passed, ${ai.checks_failed} failed`}
                . This is an AI recommendation — the final decision is yours.
              </p>
            </div>
          ) : (
            <p className="text-sm text-slate-400 py-2">AI check unavailable for this provider.</p>
          )}
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {documents.map((doc, index) => (
            <div key={index} className="flex flex-col space-y-3 p-4 bg-gray-50 rounded-2xl border border-gray-100">
              <div className="flex items-center justify-between">
                <span className="text-sm font-semibold text-gray-700 flex items-center space-x-2">
                  {doc.type === 'video' ? <Video size={16} /> : <FileText size={16} />}
                  <span>{doc.label}</span>
                </span>
                <a 
                  href={doc.url} 
                  target="_blank" 
                  rel="noopener noreferrer"
                  className="text-teal-600 hover:text-teal-700 text-xs font-medium flex items-center space-x-1"
                >
                  <span>Open Original</span>
                  <ExternalLink size={12} />
                </a>
              </div>
              
              <div className="aspect-video w-full bg-dark-900 rounded-xl overflow-hidden flex items-center justify-center border border-gray-200 shadow-inner">
                {doc.type === 'image' ? (
                  <img src={doc.url} alt={doc.label} className="w-full h-full object-contain" />
                ) : doc.type === 'video' ? (
                  <video src={doc.url} controls className="w-full h-full" />
                ) : (
                  <div className="text-white text-sm opacity-50">Unsupported Preview</div>
                )}
              </div>
            </div>
          ))}
        </div>

        <div className="bg-sky-50 border border-sky-100 p-4 rounded-2xl flex items-start space-x-3">
          <AlertCircle className="text-sky-600 flex-shrink-0 mt-0.5" size={18} />
          <div>
            <h4 className="text-sm font-bold text-sky-800">Verification Checklist</h4>
            <ul className="text-xs text-sky-700 mt-1 space-y-1 list-disc list-inside">
              <li>National ID front image is readable and valid.</li>
              <li>National ID back image matches the same applicant.</li>
              <li>Medical license is current and matches provider identity.</li>
            </ul>
          </div>
        </div>

        <div className="flex items-center justify-end space-x-3 pt-4 border-t border-gray-100">
          <button
            onClick={onReject}
            className="px-6 py-2.5 rounded-xl border border-red-200 text-red-600 font-bold text-sm hover:bg-red-50 transition-colors"
          >
            Reject Application
          </button>
          <button
            onClick={onApprove}
            className="px-6 py-2.5 rounded-xl bg-teal-600 text-white font-bold text-sm hover:bg-teal-700 shadow-lg shadow-teal-600/20 transition-all flex items-center space-x-2"
          >
            <CheckCircle size={18} />
            <span>Approve Provider</span>
          </button>
        </div>
      </div>
    </Modal>
  );
};

export default DocumentReviewModal;
