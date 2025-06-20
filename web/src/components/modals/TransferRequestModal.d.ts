import { Property } from "@/types";
interface TransferRequestModalProps {
    isOpen: boolean;
    onClose: () => void;
    item: Property;
    onTransferSuccess?: () => void;
}
declare const TransferRequestModal: React.FC<TransferRequestModalProps>;
export default TransferRequestModal;
