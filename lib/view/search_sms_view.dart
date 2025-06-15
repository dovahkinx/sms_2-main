// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/sms_cubit.dart';
import 'chat_messages_view.dart';
import '../model/search_sms_model.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  var searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Center(
          child: BlocConsumer<SmsCubit, SmsState>(
            listener: (context, state) {
              print("Search Result: ${state.search}");
            },
            builder: (context, state) {
              return Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                  textfield(context),
                  Expanded(
                    child: list(state),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  TextField textfield(BuildContext context) {
    return TextField(
      autofocus: true,
      onChanged: (value) {
        context.read<SmsCubit>().onSearch(value);
      },
      controller: searchController,
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration(
        hintText: "Ara",
        fillColor: Colors.grey[200],
        filled: true,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        border: const OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        prefixIcon: const Icon(Icons.search, color: Colors.grey),
      ),
    );
  }

  ListView list(SmsState state) {
    Map<String, List<SearchSmsMessageModel>> grouped = {};

    for (var item in state.searchResult) {
      String name = item.name!;
      grouped.update(name, (value) => value..add(item), ifAbsent: () => [item]);
    }
    return ListView.builder(
      itemCount: grouped.length,
      itemBuilder: (BuildContext context, int index) {
        return ExpansionTile(
          title: Text(grouped.keys.elementAt(index)),
          subtitle:
              Text("Toplam Mesaj: ${grouped.values.elementAt(index).length}"),
          children: [
            for (var item in grouped.values.elementAt(index))
              ListTile(
                title: Text(item.body!),
                subtitle: Text(item.date!.toString().substring(0, 16)),
                onTap: () {
                  context.read<SmsCubit>().filterMessageForAdress(item.address ?? '');
                  _navigateToChatScreen(context, item.name!, item.address!);
                },
              ),
          ],
        );
      },
    );
  }

  _navigateToChatScreen(BuildContext context, String name, String address) {
    Navigator.push(
      // Navigate to the second screen using a named route.
      context,
      MaterialPageRoute(
        builder: (context) => MessageScreen(
          address: address,
          name: name,
        ),
      ),
    );
  }
}
