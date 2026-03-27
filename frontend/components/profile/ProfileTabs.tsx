"use client";

import { useRef, useState, useEffect } from "react";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { ChevronLeft, ChevronRight } from "lucide-react";

interface TabDefinition {
  value: string;
  label: string;
  content: React.ReactNode;
}

interface ProfileTabsProps {
  tabs: TabDefinition[];
  defaultTab?: string;
}

export function ProfileTabs({ tabs, defaultTab }: ProfileTabsProps) {
  const scrollRef = useRef<HTMLDivElement>(null);
  const [canScrollLeft, setCanScrollLeft] = useState(false);
  const [canScrollRight, setCanScrollRight] = useState(true);

  const checkScroll = () => {
    if (scrollRef.current) {
      const { scrollLeft, scrollWidth, clientWidth } = scrollRef.current;
      setCanScrollLeft(scrollLeft > 0);
      setCanScrollRight(Math.ceil(scrollLeft + clientWidth) < scrollWidth);
    }
  };

  useEffect(() => {
    checkScroll();
    window.addEventListener("resize", checkScroll);
    return () => window.removeEventListener("resize", checkScroll);
  }, []);

  const scroll = (direction: "left" | "right") => {
    if (scrollRef.current) {
      const scrollAmount = 250;
      scrollRef.current.scrollBy({
        left: direction === "left" ? -scrollAmount : scrollAmount,
        behavior: "smooth",
      });
      setTimeout(checkScroll, 300); // Check again after animation
    }
  };

  return (
    <Tabs defaultValue={defaultTab ?? tabs[0]?.value} className="mt-5 w-full">
      <div className="relative group flex items-center bg-slate-100/80 backdrop-blur-sm p-1.5 rounded-xl border border-slate-200/50 shadow-sm w-full">
        
        {/* Left Arrow Indicator */}
        <button
          onClick={() => scroll("left")}
          disabled={!canScrollLeft}
          className={`absolute left-0.5 z-10 flex h-full w-8 items-center justify-center rounded-l-lg bg-gradient-to-r from-slate-100 via-slate-100 to-transparent transition-opacity duration-300 ${
            canScrollLeft ? "opacity-100" : "opacity-0 pointer-events-none"
          }`}
          aria-label="Scroll left"
        >
          <ChevronLeft className="w-5 h-5 text-slate-600 hover:text-slate-900 drop-shadow-sm" />
        </button>

        <div 
          ref={scrollRef}
          onScroll={checkScroll}
          className="flex-1 overflow-x-auto scrollbar-hide py-0.5 px-6 mx-2"
          style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }}
        >
          <TabsList className="flex h-auto gap-2 bg-transparent p-0 w-max">
            {tabs.map((tab) => (
              <TabsTrigger
                key={tab.value}
                value={tab.value}
                className="px-5 py-2.5 text-sm font-medium transition-all data-[state=active]:bg-[#1d3459] data-[state=active]:text-white data-[state=active]:shadow-md rounded-lg"
              >
                {tab.label}
              </TabsTrigger>
            ))}
          </TabsList>
        </div>

        {/* Right Arrow Indicator */}
        <button
          onClick={() => scroll("right")}
          disabled={!canScrollRight}
          className={`absolute right-0.5 z-10 flex h-full w-8 items-center justify-center rounded-r-lg bg-gradient-to-l from-slate-100 via-slate-100 to-transparent transition-opacity duration-300 ${
            canScrollRight ? "opacity-100" : "opacity-0 pointer-events-none"
          }`}
          aria-label="Scroll right"
        >
          <ChevronRight className="w-5 h-5 text-slate-600 hover:text-slate-900 drop-shadow-sm" />
        </button>
      </div>

      <div className="mt-6">
        {tabs.map((tab) => (
          <TabsContent key={tab.value} value={tab.value} className="m-0 focus-visible:outline-none focus-visible:ring-0">
            {tab.content}
          </TabsContent>
        ))}
      </div>
    </Tabs>
  );
}
