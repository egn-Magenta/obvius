function get_documents()
{
    multiselect_select_all()

    var str = $("#documents_select").serializeArray();
    $("#result").html( '' );
    $("#result").load( '/admin/?obvius_app_newsletter_helper=1', str );



}