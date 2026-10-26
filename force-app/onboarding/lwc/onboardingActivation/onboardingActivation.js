import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getActivationContext from '@salesforce/apex/OnboardingController.getActivationContext';
import activate from '@salesforce/apex/OnboardingController.activate';

const PROVISIONAL_PREFIX = 'PRE-';

function errorMessage(error) {
    if (error && error.body && error.body.message) {
        return error.body.message;
    }
    return (error && error.message) || 'Erro desconhecido.';
}

function formatDate(iso) {
    if (!iso) {
        return 'sem data';
    }
    const [year, month, day] = iso.split('-');
    return `${day}/${month}/${year}`;
}

export default class OnboardingActivation extends LightningElement {
    context;
    loading = true;
    loadError;
    busy = false;
    formError;

    employeeId;
    employeeNumber = '';
    hireDate;
    managerId;
    positionId;

    connectedCallback() {
        this.load();
    }

    async load() {
        this.loading = true;
        try {
            this.context = await getActivationContext();
            this.loadError = undefined;
        } catch (e) {
            this.loadError = errorMessage(e);
        } finally {
            this.loading = false;
        }
    }

    get showEmpty() {
        return !this.loading && !this.loadError && Boolean(this.context) && this.context.employees.length === 0;
    }

    get showForm() {
        return !this.loading && !this.loadError && Boolean(this.context) && this.context.employees.length > 0;
    }

    get employeeOptions() {
        return this.context.employees.map((e) => ({
            value: e.id,
            label: `${e.name} (início previsto em ${formatDate(e.hireDate)})`
        }));
    }

    get positionOptions() {
        return this.context.positions.map((p) => ({ value: p.value, label: p.label }));
    }

    get managerOptions() {
        return this.context.managers.map((m) => ({ value: m.value, label: m.label }));
    }

    get selectedEmployee() {
        return this.context && this.employeeId ? this.context.employees.find((e) => e.id === this.employeeId) : undefined;
    }

    get hasSelection() {
        return Boolean(this.selectedEmployee);
    }

    get provisionalNumber() {
        const e = this.selectedEmployee;
        return e && e.employeeNumber ? e.employeeNumber : '';
    }

    get submitDisabled() {
        return this.busy || !this.employeeId;
    }

    handleEmployeeChange(event) {
        this.employeeId = event.detail.value;
        this.formError = undefined;
        const e = this.selectedEmployee;
        this.employeeNumber = '';
        this.hireDate = e ? e.hireDate : undefined;
        this.managerId = e ? e.managerId : undefined;
        this.positionId = e ? e.positionId : undefined;
    }

    handleNumberChange(event) {
        this.employeeNumber = event.detail.value || '';
    }

    handleDateChange(event) {
        this.hireDate = event.detail.value;
    }

    handleManagerChange(event) {
        this.managerId = event.detail.value;
    }

    handlePositionChange(event) {
        this.positionId = event.detail.value;
    }

    validate() {
        const number = this.employeeNumber.trim();
        if (!number) {
            return 'Informe a matrícula.';
        }
        if (number.toUpperCase().startsWith(PROVISIONAL_PREFIX)) {
            return 'Informe a matrícula definitiva: o prefixo PRE- é só da pré-admissão.';
        }
        if (!this.hireDate) {
            return 'Informe a data de admissão.';
        }
        if (!this.positionId) {
            return 'Informe o cargo: ele é necessário para o histórico de admissão.';
        }
        return undefined;
    }

    async handleSubmit() {
        this.formError = this.validate();
        if (this.formError) {
            return;
        }
        this.busy = true;
        try {
            await activate({
                employeeId: this.employeeId,
                employeeNumber: this.employeeNumber.trim(),
                hireDate: this.hireDate,
                managerId: this.managerId || null,
                positionId: this.positionId || null
            });
            const name = this.selectedEmployee ? this.selectedEmployee.name : 'Colaborador';
            this.dispatchEvent(new ShowToastEvent({ title: 'Colaborador ativado', message: `${name} agora está ativo.`, variant: 'success' }));
            this.employeeId = undefined;
            this.employeeNumber = '';
            this.hireDate = undefined;
            this.managerId = undefined;
            this.positionId = undefined;
            await this.load();
        } catch (e) {
            this.formError = errorMessage(e);
        } finally {
            this.busy = false;
        }
    }
}
