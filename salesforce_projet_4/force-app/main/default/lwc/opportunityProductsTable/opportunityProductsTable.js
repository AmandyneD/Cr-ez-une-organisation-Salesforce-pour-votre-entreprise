import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import getOpportunityProducts from '@salesforce/apex/OpportunityProductsService.getOpportunityProducts';
import deleteOpportunityLine from '@salesforce/apex/OpportunityProductsService.deleteOpportunityLine';
import getCurrentProfileInfo from '@salesforce/apex/UserProfileService.getCurrentProfileInfo';

export default class OpportunityProductsTable extends NavigationMixin(LightningElement) {
    @api recordId; // Id de l’Opportunity

    @track products = [];
    @track error;
    @track isLoading = false;
    @track showStockError = false;

    isAdmin = false;
    isCommercial = false;

    columns = [];

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
                label: 'Produit',
                fieldName: 'productName',
                type: 'text'
            },
            {
                label: 'Quantité',
                fieldName: 'quantity',
                type: 'number',
                cellAttributes: { class: { fieldName: 'qtyCssClass' } }
            },
            {
                label: 'Prix unitaire',
                fieldName: 'unitPrice',
                type: 'currency'
            },
            {
                label: 'Prix total',
                fieldName: 'totalPrice',
                type: 'currency'
            },
            {
                label: 'Stock restant',
                fieldName: 'remainingStock',
                type: 'number',
                cellAttributes: { class: { fieldName: 'remainingCssClass' } }
            },
            {
                label: 'Stock initial',
                fieldName: 'quantityInStock',
                type: 'number'
            }
        ];

        const deleteColumn = {
            type: 'button-icon',
            initialWidth: 50,
            typeAttributes: {
                iconName: 'utility:delete',
                name: 'delete',
                title: 'Supprimer',
                variant: 'border-filled',
                alternativeText: 'Supprimer'
            }
        };

        const viewColumn = {
            label: 'Voir produit',
            type: 'button',
            initialWidth: 120,
            typeAttributes: {
                label: 'Voir produit',
                name: 'view',
                title: 'Voir la fiche produit',
                variant: 'base'
            }
        };

        // Admin : Voir + colonnes + Supprimer
        if (this.isAdmin) {
            return [viewColumn, ...baseColumns, deleteColumn];
        }

        // Commercial : seulement Supprimer
        return [...baseColumns, deleteColumn];
    }

    // ======================= DONNÉES =======================

    async loadProducts() {
        try {
            const data = await getOpportunityProducts({ opportunityId: this.recordId });

            this.error = undefined;
            this.showStockError = false;

            if (!data || data.length === 0) {
                this.products = [];
                return;
            }

            let hasNegative = false;

            // Texte rouge + gras via SLDS (fonctionne dans lightning-datatable)
            const negativeClasses = 'slds-text-color_error slds-text-title_bold';

            this.products = data.map((row) => {
                const quantity = row.quantity || 0;
                const quantityInStock = row.quantityInStock || 0;
                const remaining = quantityInStock - quantity;

                const isNegative = remaining < 0;
                if (isNegative) {
                    hasNegative = true;
                }

                return {
                    ...row,
                    remainingStock: remaining,
                    // cellule "Stock restant"
                    remainingCssClass: isNegative ? negativeClasses : '',
                    // cellule "Quantité"
                    qtyCssClass: isNegative ? negativeClasses : ''
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