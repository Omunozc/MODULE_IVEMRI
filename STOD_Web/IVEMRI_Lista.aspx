<%@ Page Title="" Language="C#" MasterPageFile="~/STODpla.Master" AutoEventWireup="true" CodeBehind="IVEMRI_Lista.aspx.cs" Inherits="STOD_Web.IVEMRI_Lista" %>

<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    <div class="table-responsive mt-3">
    <asp:GridView ID="GridView1" runat="server" 
        CssClass="table table-striped table-bordered table-hover" 
        AutoGenerateColumns="false" 
        EmptyDataText="No hay registros para mostrar.">
        <HeaderStyle CssClass="thead-dark" />
<Columns>
    <asp:BoundField DataField="FechaHoraSolicitud" HeaderText="Fecha y Hora" 
        DataFormatString="{0:dd/MM/yyyy HH:mm}" />
    
    <asp:BoundField DataField="DocEntryBuscado" HeaderText="ID SAP" 
        ItemStyle-HorizontalAlign="Center" />
    
    <asp:BoundField DataField="NumeroFactura" HeaderText="Factura" 
        ItemStyle-Font-Bold="true" />
    
    <asp:BoundField DataField="STOD" HeaderText="Usuario" />
    
    <asp:TemplateField HeaderText="Estado">
        <ItemTemplate>
            <span class="badge badge-success">
                <%# Eval("Mensaje") %>
            </span>
        </ItemTemplate>
    </asp:TemplateField>
</Columns>
    </asp:GridView>
</div>
    
    <div class="container mt-4">
        <div class="card shadow-sm">
            <div class="card-header bg-primary text-white">
                <h5 class="mb-0">Consulta Matriz de Riesgo IVEMRI</h5>
            </div>
            <div class="card-body">
                <div class="row align-items-end">
                    <div class="col-md-6">
                        <asp:Label ID="lblFactura" runat="server" Text="Número de Factura:" Font-Bold="true"></asp:Label>
                        
                        <asp:TextBox ID="txtNumeroFactura" runat="server" 
                            CssClass="form-control" 
                            placeholder="Ej. IN-123456..." 
                            autocomplete="off" 
                            MaxLength="50"></asp:TextBox>
                        
                        <asp:RequiredFieldValidator ID="rfvFactura" runat="server" 
                            ControlToValidate="txtNumeroFactura" 
                            ErrorMessage="* Por favor ingrese un número de factura." 
                            ForeColor="Red" 
                            ValidationGroup="GrupoBusqueda" 
                            Display="Dynamic" 
                            CssClass="small"></asp:RequiredFieldValidator>
                    </div>

                    <div class="col-md-6 mt-3 mt-md-0">
                        <asp:Button ID="btnConsultar" runat="server" Text="Consultar Matriz" 
                            CssClass="btn btn-primary" 
                            ValidationGroup="GrupoBusqueda" 
                            OnClick="btnConsultar_Click" />

                    </div>
                </div>
            </div>
        </div>

        <div class="mt-3">
            <asp:Label ID="lblMensaje" runat="server" Font-Bold="true" Font-Size="11pt"></asp:Label>
        </div>

        <div class="table-responsive mt-3">
          <asp:GridView ID="gvResultado" runat="server" AutoGenerateColumns="false"
    CssClass="table table-bordered table-striped table-hover"
    AllowPaging="true" PageSize="20">
    
    <PagerStyle HorizontalAlign="Center" CssClass="pagination-container" />
    
    <Columns>
        <asp:BoundField DataField="FechaHoraSolicitud" HeaderText="Fecha y Hora">
            <ItemStyle CssClass="centro-btn" />
        </asp:BoundField>

        <asp:BoundField DataField="NumeroFactura" HeaderText="No. Factura">
            <ItemStyle CssClass="centro-btn" />
        </asp:BoundField>

        <asp:BoundField DataField="STOD" HeaderText="Usuario STOD">
            <ItemStyle CssClass="izquierda-txt" />
        </asp:BoundField>

        <asp:BoundField DataField="Mensaje" HeaderText="Mensaje">
            <ItemStyle CssClass="izquierda-txt" />
        </asp:BoundField>
    </Columns>
</asp:GridView>
        </div>
    </div>
</asp:Content>
