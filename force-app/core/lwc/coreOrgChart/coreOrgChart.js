import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getInitial from '@salesforce/apex/OrgChartController.getInitial';
import getChildren from '@salesforce/apex/OrgChartController.children';
import searchEmployees from '@salesforce/apex/OrgChartController.search';

const SEARCH_DELAY_MS = 300;

function errorMessage(error) {
    if (!error) {
        return 'Erro desconhecido.';
    }
    if (error.body && error.body.message) {
        return error.body.message;
    }
    return error.message || 'Erro desconhecido.';
}

export default class CoreOrgChart extends NavigationMixin(LightningElement) {
    @api recordId;

    loading = true;
    error;
    emptyMessage;
    isHr = false;
    manager;
    tree = [];
    searchTerm = '';
    results = [];
    searching = false;
    searchTimer;

    connectedCallback() {
        this.load();
    }

    async load() {
        this.loading = true;
        this.error = undefined;
        try {
            const view = await getInitial({ employeeId: this.recordId || null });
            this.isHr = view.isHr;
            this.emptyMessage = view.emptyMessage;
            this.manager = view.manager ? this.toNode(view.manager) : undefined;
            const reports = (view.reports || []).map((r) => this.toNode(r));
            this.tree = (view.focus || []).map((f) => {
                const node = this.toNode(f);
                if (view.focus.length === 1) {
                    node.children = reports;
                    node.loaded = true;
                    node.expanded = reports.length > 0;
                }
                return node;
            });
        } catch (e) {
            this.error = errorMessage(e);
        } finally {
            this.loading = false;
        }
    }

    toNode(dto) {
        return { ...dto, children: [], loaded: false, expanded: false, loadingChildren: false };
    }

    get hasTree() {
        return this.tree.length > 0;
    }

    get showEmpty() {
        return !this.loading && !this.error && !this.hasTree && this.emptyMessage;
    }

    get hasResults() {
        return this.results.length > 0;
    }

    get showNoResults() {
        return !this.searching && this.searchTerm.trim().length >= 2 && this.results.length === 0;
    }

    /** Arvore achatada em linhas com nivel, para renderizar como role="tree" com indentacao. */
    get rows() {
        const out = [];
        const walk = (nodes, level) => {
            nodes.forEach((n) => {
                out.push({
                    ...n,
                    key: n.id,
                    level,
                    ariaLevel: String(level),
                    ariaExpanded: n.hasChildren ? String(n.expanded) : undefined,
                    indentStyle: `padding-left: ${(level - 1) * 1.5}rem`,
                    toggleIcon: n.expanded ? 'utility:chevrondown' : 'utility:chevronright',
                    toggleLabel: n.expanded ? `Recolher equipe de ${n.name}` : `Expandir equipe de ${n.name}`,
                    reportsLabel: n.directReports === 1 ? '1 subordinado' : `${n.directReports} subordinados`
                });
                if (n.expanded) {
                    walk(n.children, level + 1);
                }
            });
        };
        walk(this.tree, 1);
        return out;
    }

    findNode(nodes, id) {
        for (const n of nodes) {
            if (n.id === id) {
                return n;
            }
            const inner = this.findNode(n.children, id);
            if (inner) {
                return inner;
            }
        }
        return undefined;
    }

    async handleToggle(event) {
        const id = event.currentTarget.dataset.id;
        const node = this.findNode(this.tree, id);
        if (!node) {
            return;
        }
        if (node.expanded) {
            node.expanded = false;
            this.tree = [...this.tree];
            return;
        }
        if (!node.loaded) {
            node.loadingChildren = true;
            this.tree = [...this.tree];
            try {
                const children = await getChildren({ employeeId: id });
                node.children = children.map((c) => this.toNode(c));
                node.loaded = true;
            } catch (e) {
                this.error = errorMessage(e);
            } finally {
                node.loadingChildren = false;
            }
        }
        node.expanded = node.children.length > 0;
        this.tree = [...this.tree];
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value || '';
        window.clearTimeout(this.searchTimer);
        if (this.searchTerm.trim().length < 2) {
            this.results = [];
            return;
        }
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.searchTimer = window.setTimeout(() => this.runSearch(), SEARCH_DELAY_MS);
    }

    async runSearch() {
        this.searching = true;
        try {
            this.results = await searchEmployees({ term: this.searchTerm });
        } catch (e) {
            this.error = errorMessage(e);
            this.results = [];
        } finally {
            this.searching = false;
        }
    }

    handleOpen(event) {
        const id = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: id, objectApiName: 'Employee__c', actionName: 'view' }
        });
    }
}
