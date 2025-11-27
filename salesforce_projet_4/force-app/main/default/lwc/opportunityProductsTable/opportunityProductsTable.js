import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import getOpportunityProducts from '@salesforce/apex/OpportunityProductsService.getOpportunityProducts';
import deleteOpportunityLine from '@salesforce/apex/OpportunityProductsService.deleteOpportunityLine';
import getCurrentProfileInfo from '@salesforce/apex/UserProfileService.getCurrentProfileInfo';

// ====== CUSTOM LABELS ======
import LBL_OpportunityProducts from '@salesforce/label/c.LBL_OpportunityProducts';
import LBL_ProductName         from '@salesforce/label/c.LBL_ProductName';
import LBL_Quantity            from '@salesforce/label/c.LBL_Quantity';
import LBL_UnitPrice           from '@salesforce/label/c.LBL_UnitPrice';
import LBL_TotalPrice          from '@salesforce/label/c.LBL_TotalPrice';
import LBL_QuantityInStock     from '@salesforce/label/c.LBL_QuantityInStock';
import LBL_Delete              from '@salesforce/label/c.LBL_Delete';
import LBL_ViewProduct         from '@salesforce/label/c.LBL_ViewProduct';
import LBL_StockWarning_Line1  from '@salesforce/label/c.LBL_StockWarning_Line1';
import LBL_StockWarning_Line2  from '@salesforce/label/c.LBL_StockWarning_Line2';
import LBL_NoProducts_Line1    from '@salesforce/label/c.LBL_NoProductsMessage_Line1';
import LBL_NoProducts_Line2    from '@salesforce/label/c.LBL_NoProductsMessage_Line2';
import LBL_NoProducts_Line3    from '@salesforce/label/c.LBL_NoProductsMessage_Line3';

export default class OpportunityProductsTable extends NavigationMixin(
    LightningElement
) {
    @api recordId; // Id de l’Opportunity

    @track products = [];
    @track error;
    @track isLoading = false;
    @track showStockError = false;

    isAdmin = false;
    isCommercial = false;

    columns = [];

    // Expose les labels au template HTML
    label = {
        opportunityProductsTitle: LBL_OpportunityProducts,
        productName:              LBL_ProductName,
        quantity:                 LBL_Quantity,
        unitPrice:                LBL_UnitPrice,
        totalPrice:               LBL_TotalPrice,
        quantityInStock:          LBL_QuantityInStock,
        delete:                   LBL_Delete,
        viewProduct:              LBL_ViewProduct,
        stockWarningLine1:        LBL_StockWarning_Line1,
        stockWarningLine2:        LBL_StockWarning_Line2,
        noProductsLine1:          LBL_NoProducts_Line1,
        noProductsLine2:          LBL_NoProducts_Line2,
        noProductsLine3:          LBL_NoProducts_Line3
    };

    // ======================= LIFE CYCLE =======================

    connectedCallback() {
        this.isLoading = true;
        this.initComponent();
    }

    async initComponent() {
        try {
            // 1) Récupérer les infos de profil
            const profileInfo = await getCurrentProfileInfo();
            this.isAdmin = profileInfo && profileInfo.isSystemAdmin;
            this.isCommercial = profileInfo && profileInfo.isCommercial;

            // 2) Construire les colonnes en fonction du profil
            this.columns = this.buildColumns();

            // 3) Charger les produits
            await this.loadProducts();
        } catch (err) {
            this.error = err;
        } finally {
            this.isLoading = false;
        }
    }

    // ======================= COLONNES =======================

    buildColumns() {
        const baseColumns = [
            {
                label: this.label.productName,
                fieldName: 'productName',
                type: 'text'
            },
            {
                label: this.label.quantity,
                fieldName: 'quantity',
                type: 'number',
                // rouge + gras si quantité liée à un stock négatif
                cellAttributes: { class: { fieldName: 'qtyCssClass' } }
            },
            {
                label: this.label.unitPrice,
                fieldName: 'unitPrice',
                type: 'currency'
            },
            {
                label: this.label.totalPrice,
                fieldName: 'totalPrice',
                type: 'currency'
            },
            {
                // Stock restant calculé dans loadProducts()
                label: this.label.quantityInStock,
                fieldName: 'remainingStock',
                type: 'number',
                // rouge + gras si remainingStock < 0
                cellAttributes: { class: { fieldName: 'remainingCssClass' } }
            }
        ];

        const deleteColumn = {
            type: 'button-icon',
            initialWidth: 50,
            typeAttributes: {
                iconName: 'utility:delete',
                name: 'delete',
                title: this.label.delete,
                variant: 'border-filled',
                alternativeText: this.label.delete
            }
        };

        const viewColumn = {
            label: this.label.viewProduct,
            type: 'button',
            initialWidth: 120,
            typeAttributes: {
                label: this.label.viewProduct,
                name: 'view',
                title: this.label.viewProduct,
                variant: 'base'
            }
        };

        // Admin : Voir + colonnes + Supprimer
        if (this.isAdmin) {
            return [viewColumn, ...baseColumns, deleteColumn];
        }

        // Commercial : colonnes + Supprimer
        return [...baseColumns, deleteColumn];
    }

    // ======================= DONNÉES =======================

    async loadProducts() {
        try {
            const data = await getOpportunityProducts({
                opportunityId: this.recordId
            });

            this.error = undefined;
            this.showStockError = false;

            if (!data || data.length === 0) {
                this.products = [];
                return;
            }

            let hasNegative = false;

            this.products = data.map((row) => {
                const quantity = row.quantity || 0;
                const quantityInStock = row.quantityInStock || 0;
                const remaining = quantityInStock - quantity;

                const isNegative = remaining < 0;
                if (isNegative) {
                    hasNegative = true;
                }

                // ⚠️ Utilisation des classes SLDS reconnues par lightning-datatable
                const negativeClass = isNegative
                    ? 'slds-text-color_error slds-text-title_bold'
                    : '';

                return {
                    ...row,
                    remainingStock: remaining,
                    remainingCssClass: negativeClass,
                    qtyCssClass: negativeClass
                };
            });

            this.showStockError = hasNegative;
        } catch (err) {
            this.error = err;
            this.products = [];
            this.showStockError = false;
        }
    }

    get hasProducts() {
        return this.products && this.products.length > 0;
    }

    // ======================= ACTIONS LIGNE =======================

    async handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        switch (actionName) {
            case 'delete':
                await this.handleDelete(row);
                break;
            case 'view':
                this.handleViewProduct(row);
                break;
            default:
        }
    }

    async handleDelete(row) {
        this.isLoading = true;
        try {
            await deleteOpportunityLine({ lineItemId: row.lineItemId });
            await this.loadProducts();
        } catch (err) {
            this.error = err;
        } finally {
            this.isLoading = false;
        }
    }

    handleViewProduct(row) {
        const productId = row.productId;
        if (!productId) {
            return;
        }

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: productId,
                actionName: 'view'
            }
        });
    }

    // ======================= GETTERS POUR LES MESSAGES =======================

    get showEmptyMessage() {
        return !this.isLoading && !this.error && !this.hasProducts;
    }

    get errorMessage() {
        if (!this.error) {
            return null;
        }
        if (this.error.body && this.error.body.message) {
            return this.error.body.message;
        }
        return this.error.message || this.error.toString();
    }
}