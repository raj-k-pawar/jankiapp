import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/models.dart';
import '../../services/storage_service.dart';
import '../../utils/app_theme.dart';
import '../shared/widgets.dart';
import '../../screens/auth/login_screen.dart';
import 'add_customer_screen.dart';
import '../../services/storage_service.dart';

class AllCustomersScreen extends StatefulWidget {
  const AllCustomersScreen({super.key});
  @override State<AllCustomersScreen> createState() => _AllCustomersScreenState();
}
class _AllCustomersScreenState extends State<AllCustomersScreen> {
  List<CustomerModel> _all=[], _filtered=[];
  bool _loading=true;
  String _search='';
  DateTime? _filterDate;
  UserModel? _currentUser;

  @override void initState(){ super.initState(); _load(); }

  Future<void> _load() async {
    setState(()=>_loading=true);
    _currentUser = await StorageService.instance.getSession();
    _all = await StorageService.instance.getCustomers();
    _apply();
    setState(()=>_loading=false);
  }

  void _apply(){
    setState((){
      _filtered = _all.where((c){
        final ms = _search.isEmpty ||
            c.name.toLowerCase().contains(_search.toLowerCase()) ||
            c.phone.contains(_search) ||
            c.city.toLowerCase().contains(_search.toLowerCase());
        final md = _filterDate==null || sameDay(c.visitDate,_filterDate!);
        return ms && md;
      }).toList();
    });
  }

  Future<void> _delete(CustomerModel c) async {
    final ok = await showDialog<bool>(context:context, builder:(ctx)=>AlertDialog(
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),
      title:Text('Delete?',style:GoogleFonts.poppins(fontWeight:FontWeight.w700)),
      content:Text('Delete booking for "${c.name}"?',style:GoogleFonts.poppins()),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
        ElevatedButton(onPressed:()=>Navigator.pop(ctx,true),
            style:ElevatedButton.styleFrom(backgroundColor:AppColors.error),
            child:const Text('Delete',style:TextStyle(color:Colors.white))),
      ],
    ));
    if (ok==true){ await StorageService.instance.deleteCustomer(c.id); _load(); }
  }

  Future<void> _pickDate() async {
    DateTime selected = _filterDate ?? DateTime.now();
    await showDialog(context:context, builder:(ctx)=>Dialog(
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),
      child:Padding(padding:const EdgeInsets.all(16), child:Column(mainAxisSize:MainAxisSize.min,children:[
        TableCalendar(
          firstDay:DateTime(2020), lastDay:DateTime(2030), focusedDay:selected,
          selectedDayPredicate:(d)=>sameDay(d,selected),
          calendarFormat:CalendarFormat.month,
          headerStyle:const HeaderStyle(formatButtonVisible:false,titleCentered:true),
          calendarStyle:const CalendarStyle(
            selectedDecoration:BoxDecoration(color:AppColors.primary,shape:BoxShape.circle),
            todayDecoration:BoxDecoration(color:Color(0xFF52B78844),shape:BoxShape.circle),
          ),
          onDaySelected:(sel,_){ selected=sel; },
        ),
        Row(mainAxisAlignment:MainAxisAlignment.end,children:[
          TextButton(onPressed:(){ _filterDate=null; _apply(); Navigator.pop(ctx); },
              child:const Text('Clear')),
          ElevatedButton(onPressed:(){ _filterDate=selected; _apply(); Navigator.pop(ctx); },
              child:const Text('Apply')),
        ]),
      ])),
    ));
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('All Customers'),
        leading:IconButton(icon:const Icon(Icons.arrow_back_ios,color:Colors.white,size:18),
            onPressed:()=>Navigator.pop(context)),
        actions:[
          IconButton(icon:const Icon(Icons.refresh,color:Colors.white),onPressed:_load),
        ],
      ),
      body: Column(children:[
        Container(
          color:AppColors.primary,
          padding:const EdgeInsets.fromLTRB(14,0,14,14),
          child:Column(children:[
            Container(height:42,
              decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10)),
              child:TextField(onChanged:(v){_search=v;_apply();},
                decoration:InputDecoration(
                  hintText:'Search name, city, phone...',
                  hintStyle:GoogleFonts.poppins(fontSize:12,color:AppColors.textLight),
                  prefixIcon:const Icon(Icons.search,color:AppColors.textLight,size:18),
                  border:InputBorder.none,
                  contentPadding:const EdgeInsets.symmetric(vertical:12),
                )),
            ),
            const SizedBox(height:8),
            Row(children:[
              GestureDetector(onTap:_pickDate,
                child:Container(
                  padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),
                  decoration:BoxDecoration(
                      color:_filterDate!=null?Colors.white:Colors.white24,
                      borderRadius:BorderRadius.circular(20)),
                  child:Row(children:[
                    Icon(Icons.calendar_today,size:13,
                        color:_filterDate!=null?AppColors.primary:Colors.white),
                    const SizedBox(width:4),
                    Text(_filterDate!=null
                        ? DateFormat('dd MMM').format(_filterDate!)
                        : 'Filter by date',
                      style:GoogleFonts.poppins(fontSize:11,fontWeight:FontWeight.w600,
                          color:_filterDate!=null?AppColors.primary:Colors.white)),
                  ]),
                ),
              ),
              if(_filterDate!=null)...[
                const SizedBox(width:8),
                GestureDetector(onTap:(){_filterDate=null;_apply();},
                  child:Container(padding:const EdgeInsets.all(5),
                    decoration:const BoxDecoration(color:Colors.white24,shape:BoxShape.circle),
                    child:const Icon(Icons.close,color:Colors.white,size:14))),
              ],
            ]),
          ]),
        ),
        Padding(padding:const EdgeInsets.fromLTRB(16,10,16,4),
          child:Text('${_filtered.length} customers',
              style:GoogleFonts.poppins(fontSize:12,color:AppColors.textLight))),
        Expanded(child:_loading
            ? const Center(child:CircularProgressIndicator(color:AppColors.primary))
            : _filtered.isEmpty
                ? Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                    Icon(Icons.people_outline,size:56,color:Colors.grey.shade300),
                    const SizedBox(height:10),
                    Text('No customers found',style:GoogleFonts.poppins(color:AppColors.textLight)),
                  ]))
                : RefreshIndicator(onRefresh:_load, color:AppColors.primary,
                    child:ListView.builder(
                      padding:const EdgeInsets.fromLTRB(14,0,14,20),
                      itemCount:_filtered.length,
                      itemBuilder:(_,i)=>_card(_filtered[i]),
                    ))),
      ]),
    );
  }

  Widget _card(CustomerModel c){
    final fmt = NumberFormat('#,##,###','en_IN');
    return Container(
      margin:const EdgeInsets.only(bottom:10),
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
          boxShadow:[BoxShadow(color:Colors.black.withOpacity(0.05),blurRadius:6,offset:const Offset(0,2))]),
      child:Padding(padding:const EdgeInsets.all(14),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            CircleAvatar(radius:20,backgroundColor:AppColors.primary.withOpacity(0.1),
              child:Text(c.name[0].toUpperCase(),style:GoogleFonts.poppins(
                  fontSize:16,fontWeight:FontWeight.w700,color:AppColors.primary))),
            const SizedBox(width:10),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(c.name,style:GoogleFonts.poppins(fontSize:13,fontWeight:FontWeight.w700,color:AppColors.textDark)),
              Text('${c.city}  •  ${c.phone}',style:GoogleFonts.poppins(fontSize:11,color:AppColors.textLight)),
            ])),
            Text('₹${fmt.format(c.totalAmount)}',style:GoogleFonts.poppins(
                fontSize:15,fontWeight:FontWeight.w700,color:AppColors.primary)),
          ]),
          const SizedBox(height:8),
          Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:4),
            decoration:BoxDecoration(color:AppColors.primary.withOpacity(0.07),
                borderRadius:BorderRadius.circular(6)),
            child:Text(c.packageName,style:GoogleFonts.poppins(
                fontSize:11,color:AppColors.primary,fontWeight:FontWeight.w500))),
          const SizedBox(height:6),
          Row(children:[
            _badge(Icons.groups_outlined,'${c.totalGuests} guests'),
            const SizedBox(width:10),
            _badge(c.paymentMode==PaymentMode.cash?Icons.money_outlined:Icons.phone_android_outlined,
                c.paymentMode==PaymentMode.cash?'Cash':'Online'),
            const SizedBox(width:10),
            _badge(Icons.person_outline,c.managerName),
            const Spacer(),
            // Edit
            if(_currentUser!=null&&(_currentUser!.role==UserRole.manager||_currentUser!.role==UserRole.owner||_currentUser!.role==UserRole.admin))
              IconButton(icon:const Icon(Icons.edit_outlined,color:AppColors.cardBlue,size:20),
                padding:EdgeInsets.zero,constraints:const BoxConstraints(),
                onPressed:() async {
                  final ok = await Navigator.push<bool>(context, MaterialPageRoute(
                      builder:(_)=>BookingFormScreen(packages:const [],
                          managerUser:_currentUser!,
                          pkg:null,
                          existing:c)));
                  if(ok==true) _load();
                }),
            const SizedBox(width:12),
            if(_currentUser!=null&&(_currentUser!.role==UserRole.owner||_currentUser!.role==UserRole.admin))
              IconButton(icon:const Icon(Icons.delete_outline,color:AppColors.error,size:20),
                padding:EdgeInsets.zero,constraints:const BoxConstraints(),
                onPressed:()=>_delete(c)),
          ]),
        ],
      )),
    );
  }

  Widget _badge(IconData icon,String label)=>Row(children:[
    Icon(icon,size:13,color:AppColors.textLight),
    const SizedBox(width:3),
    Text(label,style:GoogleFonts.poppins(fontSize:11,color:AppColors.textMedium)),
  ]);
}
