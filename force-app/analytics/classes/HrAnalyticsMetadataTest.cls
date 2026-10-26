/**
 * Garante que os relatorios e o painel do modulo analytics foram implantados na pasta "RH Core".
 * Os dados de relatorios e paineis so ficam visiveis para o Apex com SeeAllData; o teste nao grava nem le dado de pessoa.
 */
// Report e Dashboard so aparecem ao Apex com SeeAllData; o teste so le metadado de pasta, nao dado de pessoa.
@SuppressWarnings('PMD.ApexUnitTestShouldNotUseSeeAllDataTrue')
@IsTest(SeeAllData=true)
private class HrAnalyticsMetadataTest {
    private static final Set<String> REPORT_NAMES = new Set<String>{
        'Headcount por departamento',
        'Férias com prazo concessivo vencendo',
        'Saldo de férias por colaborador',
        'Funil de recrutamento por etapa',
        'Tempo médio por etapa',
        'Avaliações por status no ciclo atual',
        'Promoções por status'
    };

    @IsTest
    static void sevenReportsExistInTheRhCoreFolder() {
        Set<String> found = new Set<String>();
        for (Report r : [SELECT Name FROM Report WHERE FolderName = 'RH Core' AND Name IN :REPORT_NAMES]) {
            found.add(r.Name);
        }
        System.assertEquals(REPORT_NAMES, found, 'Todos os relatórios da pasta RH Core devem estar implantados.');
    }

    @IsTest
    static void dashboardPainelDoRhExists() {
        List<Dashboard> boards = [SELECT Id FROM Dashboard WHERE FolderName = 'RH Core' AND Title = 'Painel do RH'];
        System.assertEquals(1, boards.size(), 'O painel do RH deve existir na pasta RH Core.');
    }
}
