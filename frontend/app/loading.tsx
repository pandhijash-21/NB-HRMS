import Image from 'next/image';

export default function Loading() {
  return (
    <div className="fixed inset-0 z-50 flex flex-col items-center justify-center bg-black/90 backdrop-blur-sm">
      <div className="relative flex items-center justify-center w-36 h-36">
        <div className="absolute inset-0 rounded-full bg-[#c5a36a]/20 animate-ping opacity-25" />
        <div className="relative w-28 h-28 rounded-full overflow-hidden border border-[#c5a36a]/40 shadow-[0_0_25px_rgba(197,163,106,0.3)] bg-[#0d0a07]">
          <Image
            src="/mrnb.gif"
            alt="Loading..."
            width={112}
            height={112}
            className="w-full h-full object-contain"
            priority
            unoptimized
          />
        </div>
      </div>
      <p className="mt-4 text-[#e8c98a] text-sm font-medium tracking-wider">
        Loading...
      </p>
    </div>
  );
}
