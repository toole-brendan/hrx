import React from "react";
import { useLocation } from "wouter";
import { ArrowRightLeft, Search, QrCode, Package } from "lucide-react";
import { QuickActionButton } from "@/components/ios";

interface QuickActionsProps {
  // QR Scanner functionality removed
}

const QuickActions: React.FC<QuickActionsProps> = () => {
  const [, navigate] = useLocation();

  const actions = [
    { 
      icon: <ArrowRightLeft className="h-4 w-4" />, 
      label: "Request Transfer", 
      onClick: () => navigate("/transfers") 
    },
    { 
      icon: <Search className="h-4 w-4" />, 
      label: "Find Item", 
      onClick: () => navigate("/property-book") 
    },
    { 
      icon: <QrCode className="h-4 w-4" />, 
      label: "Scan QR Code", 
      onClick: () => {
        // TODO: Implement QR scanner
        console.log("QR Scanner not yet implemented");
      }
    },
    { 
      icon: <Package className="h-4 w-4" />, 
      label: "Add Property", 
      onClick: () => navigate("/property-book") 
    },
  ];

  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
      {actions.map((action, index) => (
        <QuickActionButton
          key={index}
          icon={action.icon}
          label={action.label}
          onClick={action.onClick}
          variant="secondary"
          className="w-full"
        />
      ))}
    </div>
  );
};

export default QuickActions;
